package com.example.jamaat_time.focusguard

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONObject

class FocusGuardAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "FocusGuard"
        private const val YOUTUBE_PACKAGE = "com.google.android.youtube"
        private const val DEBOUNCE_MS = 2000L
        private const val KEY_TEMP_ALLOW_EXPIRY = "focus_guard_temp_allow_expiry"
    }

    private var lastActionTime = 0L
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        // Re-apply flags programmatically in case an OEM build ignores XML config.
        // flagReportViewIds is required for node.viewIdResourceName to be populated.
        val info = serviceInfo ?: AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.notificationTimeout = 300
        info.packageNames = arrayOf(YOUTUBE_PACKAGE)
        info.flags = info.flags or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        serviceInfo = info
        Log.d(TAG, "Service connected; flags=${info.flags}")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val packageName = event.packageName?.toString() ?: return
        if (packageName != YOUTUBE_PACKAGE) return

        val settings = readSettings() ?: return
        if (!settings.enabled) return
        if (!settings.youtubeBlocked) return

        val now = System.currentTimeMillis()
        if (isTempAllowed(now)) return
        if (now - lastActionTime < DEBOUNCE_MS) return

        if (!detectShorts(event)) return

        lastActionTime = now
        Log.d(TAG, "SHORTS_DETECTED — blocking")
        performGlobalAction(GLOBAL_ACTION_BACK)
        showOverlay(settings.tempAllowMinutes, settings.quickAllowEnabled)
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        dismissOverlay()
        super.onDestroy()
    }

    // --- Detection ---

    private fun detectShorts(event: AccessibilityEvent): Boolean {
        val className = event.className?.toString() ?: ""
        if (className.contains("Shorts", ignoreCase = true) ||
            className.contains("ReelWatch", ignoreCase = true)) {
            Log.d(TAG, "Shorts hit via className=$className")
            return true
        }

        val root = rootInActiveWindow ?: return false
        if (findShortsViewId(root, 0)) {
            Log.d(TAG, "Shorts hit via reel/shorts view id")
            return true
        }
        return false
    }

    private fun findShortsViewId(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > 25) return false
        val id = node.viewIdResourceName
        if (id != null && (
                id.contains("reel_", ignoreCase = true) ||
                id.contains("_reel", ignoreCase = true) ||
                id.contains("shorts_", ignoreCase = true) ||
                id.contains("_shorts", ignoreCase = true)
            )) {
            return true
        }
        for (i in 0 until node.childCount) {
            if (findShortsViewId(node.getChild(i), depth + 1)) return true
        }
        return false
    }

    // --- Settings ---

    private data class NativeSettings(
        val enabled: Boolean,
        val youtubeBlocked: Boolean,
        val tempAllowMinutes: Int,
        val quickAllowEnabled: Boolean,
    )

    private fun readSettings(): NativeSettings? {
        val prefs = getSharedPreferences(FocusGuardChannel.NATIVE_PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(FocusGuardChannel.KEY_SETTINGS_JSON, null) ?: return null
        return try {
            val json = JSONObject(raw)
            val apps = json.optJSONObject("blockedApps")
            NativeSettings(
                enabled = json.optBoolean("enabled", false),
                youtubeBlocked = apps?.optBoolean("youtube", false) ?: false,
                tempAllowMinutes = json.optInt("tempAllowMinutes", 10),
                quickAllowEnabled = json.optBoolean("quickAllowEnabled", false),
            )
        } catch (_: Throwable) {
            null
        }
    }

    private fun isTempAllowed(now: Long): Boolean {
        val prefs = getSharedPreferences(FocusGuardChannel.NATIVE_PREFS, Context.MODE_PRIVATE)
        val expiry = prefs.getLong(KEY_TEMP_ALLOW_EXPIRY, 0L)
        return expiry > now
    }

    private fun setTempAllow(minutes: Int) {
        val prefs = getSharedPreferences(FocusGuardChannel.NATIVE_PREFS, Context.MODE_PRIVATE)
        val expiry = System.currentTimeMillis() + minutes * 60_000L
        prefs.edit().putLong(KEY_TEMP_ALLOW_EXPIRY, expiry).apply()
    }

    // --- Overlay ---

    private fun showOverlay(tempAllowMinutes: Int, quickAllowEnabled: Boolean) {
        if (overlayView != null) return
        if (!Settings.canDrawOverlays(this)) {
            Log.w(TAG, "Overlay permission not granted — skipping overlay")
            return
        }

        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        windowManager = wm

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        )
        params.gravity = Gravity.CENTER

        val view = FocusGuardOverlayViewFactory.create(
            context = this,
            tempAllowMinutes = tempAllowMinutes,
            quickAllowEnabled = quickAllowEnabled,
            onGoBack = {
                dismissOverlay()
                performGlobalAction(GLOBAL_ACTION_BACK)
            },
            onAllow = { minutes ->
                setTempAllow(minutes)
                dismissOverlay()
            },
        )
        try {
            wm.addView(view, params)
            overlayView = view
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to add overlay", t)
        }
    }

    private fun dismissOverlay() {
        val view = overlayView ?: return
        try {
            windowManager?.removeView(view)
        } catch (_: Throwable) {
            // Already removed.
        }
        overlayView = null
    }

}
