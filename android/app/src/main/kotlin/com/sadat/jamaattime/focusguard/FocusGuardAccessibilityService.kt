package com.sadat.jamaattime.focusguard

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.os.Build
import android.util.Log
import android.view.Display
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.sadat.jamaattime.familysafety.vpn.ActivitySummaryWriter
import org.json.JSONObject

class FocusGuardAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "FocusGuard"
        private const val YOUTUBE_PACKAGE = "com.google.android.youtube"
        private const val DEBOUNCE_MS = 2000L
    }

    private var lastActionTime = 0L
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    private var overlayContext: Context? = null
    private val activityWriter by lazy { ActivitySummaryWriter(applicationContext) }
    private val blockCountGate by lazy {
        FocusGuardBlockCountGate { category -> activityWriter.increment(category) }
    }

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
        info.flags = (info.flags and
                AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS.inv()) or
                AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
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
        val tempAllowed = isTempAllowed(now)
        if (!settings.quickAllowEnabled && tempAllowed) {
            clearTempAllow("quick_bypass_disabled")
        }
        if (settings.quickAllowEnabled && tempAllowed) return
        if (now - lastActionTime < DEBOUNCE_MS) return

        if (!detectShorts(event)) return

        lastActionTime = now
        Log.d(TAG, "SHORTS_DETECTED — blocking")
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
        val expiry = prefs.getLong(FocusGuardChannel.KEY_TEMP_ALLOW_EXPIRY, 0L)
        return expiry > now
    }

    private fun setTempAllow(minutes: Int) {
        val prefs = getSharedPreferences(FocusGuardChannel.NATIVE_PREFS, Context.MODE_PRIVATE)
        val expiry = System.currentTimeMillis() + minutes * 60_000L
        prefs.edit().putLong(FocusGuardChannel.KEY_TEMP_ALLOW_EXPIRY, expiry).apply()
    }

    private fun clearTempAllow(reason: String) {
        val prefs = getSharedPreferences(FocusGuardChannel.NATIVE_PREFS, Context.MODE_PRIVATE)
        prefs.edit().remove(FocusGuardChannel.KEY_TEMP_ALLOW_EXPIRY).apply()
        Log.d(TAG, "Temp allow revoked due to $reason")
    }

    // --- Overlay ---

    private fun showOverlay(tempAllowMinutes: Int, quickAllowEnabled: Boolean) {
        if (overlayView != null) return

        val context = createOverlayContext()
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        overlayContext = context
        windowManager = wm

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        )
        params.gravity = Gravity.CENTER

        val view = FocusGuardOverlayViewFactory.create(
            context = context,
            tempAllowMinutes = tempAllowMinutes,
            quickAllowEnabled = quickAllowEnabled,
            onGoBack = {
                // HOME exits YouTube in one step regardless of Shorts' internal
                // back-stack. Dispatch before dismissing the overlay so the
                // launcher is already coming forward when our window tears down.
                performGlobalAction(GLOBAL_ACTION_HOME)
                // Re-arm debounce so trailing YouTube events from the transition
                // cannot resurrect the overlay on top of the launcher.
                lastActionTime = System.currentTimeMillis()
                dismissOverlay()
            },
            onAllow = { minutes ->
                setTempAllow(minutes)
                dismissOverlay()
            },
        )
        try {
            wm.addView(view, params)
            overlayView = view
            try {
                blockCountGate.onConfirmedBlockOverlayShown()
            } catch (t: Throwable) {
                Log.w(TAG, "Failed to increment Focus Guard block count", t)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to add overlay", t)
            overlayContext = null
        }
    }

    private fun createOverlayContext(): Context {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return this
        return try {
            val displayManager = getSystemService(DisplayManager::class.java)
            val display = displayManager.getDisplay(Display.DEFAULT_DISPLAY)
            createDisplayContext(display).createWindowContext(
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                null,
            )
        } catch (t: Throwable) {
            Log.w(TAG, "Falling back to service context for accessibility overlay", t)
            this
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
        overlayContext = null
        blockCountGate.onOverlayDismissed()
    }

}
