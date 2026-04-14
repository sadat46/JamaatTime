package com.example.jamaat_time.focusguard

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
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
        showOverlay(settings.tempAllowMinutes)
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        dismissOverlay()
        super.onDestroy()
    }

    // --- Detection ---

    private fun detectShorts(event: AccessibilityEvent): Boolean {
        val className = event.className?.toString() ?: ""
        val strongSignal = className.contains("Shorts", ignoreCase = true) ||
            className.contains("shorts", ignoreCase = true)
        if (strongSignal) return true

        val root = rootInActiveWindow ?: return false
        val weakA = findShortsTextSignal(root)
        val weakB = findVerticalFeedSignal(root)
        return weakA && weakB
    }

    private fun findShortsTextSignal(root: AccessibilityNodeInfo): Boolean {
        return try {
            val nodes = root.findAccessibilityNodeInfosByText("Shorts") ?: emptyList()
            nodes.any { n ->
                val desc = n.contentDescription?.toString()?.lowercase() ?: ""
                n.isSelected || desc.contains("selected") || desc.contains("shorts tab")
            }
        } catch (_: Throwable) {
            false
        }
    }

    private fun findVerticalFeedSignal(root: AccessibilityNodeInfo): Boolean {
        return hasVerticalScrollingContainer(root, depth = 0)
    }

    private fun hasVerticalScrollingContainer(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > 12) return false
        val cn = node.className?.toString() ?: ""
        if ((cn.contains("ViewPager") || cn.contains("RecyclerView")) && node.isScrollable) {
            return true
        }
        for (i in 0 until node.childCount) {
            if (hasVerticalScrollingContainer(node.getChild(i), depth + 1)) return true
        }
        return false
    }

    // --- Settings ---

    private data class NativeSettings(
        val enabled: Boolean,
        val youtubeBlocked: Boolean,
        val tempAllowMinutes: Int,
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

    private fun showOverlay(tempAllowMinutes: Int) {
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

        val view = buildOverlayView(tempAllowMinutes)
        try {
            wm.addView(view, params)
            overlayView = view
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to add overlay", t)
        }
    }

    private fun buildOverlayView(tempAllowMinutes: Int): View {
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#CC000000"))
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            val pad = dp(24)
            setPadding(pad, pad, pad, pad)
            val bg = GradientDrawable().apply {
                cornerRadius = dp(20).toFloat()
                setColor(Color.parseColor("#FF1B1B1B"))
            }
            background = bg
            val lp = FrameLayout.LayoutParams(
                dp(300),
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER,
            )
            layoutParams = lp
        }

        card.addView(
            TextView(this).apply {
                text = "Focus Guard Active"
                setTextColor(Color.WHITE)
                textSize = 20f
                setTypeface(typeface, android.graphics.Typeface.BOLD)
                gravity = Gravity.CENTER
            }
        )

        card.addView(
            TextView(this).apply {
                text = "Short videos are blocked to help you stay focused."
                setTextColor(Color.parseColor("#CCFFFFFF"))
                textSize = 14f
                gravity = Gravity.CENTER
                val lp = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                )
                lp.topMargin = dp(10)
                lp.bottomMargin = dp(20)
                layoutParams = lp
            }
        )

        card.addView(
            Button(this).apply {
                text = "Go Back"
                setOnClickListener {
                    dismissOverlay()
                    performGlobalAction(GLOBAL_ACTION_BACK)
                }
                val lp = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                )
                layoutParams = lp
            }
        )

        card.addView(
            Button(this).apply {
                text = "Allow $tempAllowMinutes min"
                setOnClickListener {
                    setTempAllow(tempAllowMinutes)
                    dismissOverlay()
                }
                val lp = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                )
                lp.topMargin = dp(8)
                layoutParams = lp
            }
        )

        root.addView(card)
        return root
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

    private fun dp(value: Int): Int {
        val density = resources.displayMetrics.density
        return (value * density).toInt()
    }
}
