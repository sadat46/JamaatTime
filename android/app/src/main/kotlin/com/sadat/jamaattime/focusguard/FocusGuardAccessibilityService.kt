package com.sadat.jamaattime.focusguard

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.graphics.PixelFormat
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
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
        private const val EXIT_CHECK_DELAY_MS = 650L
        private const val EXIT_RECHECK_DELAY_MS = 400L
        private const val EXIT_CHECK_ATTEMPTS = 4
        private const val MAX_NODE_SEARCH_DEPTH = 25
        private val TEMP_ALLOW_OPTIONS = setOf(5, 10, 15)
    }

    private var lastActionTime = 0L
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    private var overlayContext: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val activityWriter by lazy { ActivitySummaryWriter(applicationContext) }
    private val blockCountGate by lazy {
        FocusGuardBlockCountGate { category -> activityWriter.increment(category) }
    }
    private val exitController by lazy {
        FocusGuardShortsExitController(
            actions = object : FocusGuardShortsExitController.Actions {
                override fun clickYoutubeHomeTab(): Boolean? {
                    val root = rootInActiveWindow ?: return null
                    if (root.packageName?.toString() != YOUTUBE_PACKAGE) return null
                    val homeTab = findYoutubeHomeTab(root) ?: return null
                    return homeTab.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                }

                override fun performSingleBackFallback(): Boolean {
                    val root = rootInActiveWindow ?: return false
                    if (root.packageName?.toString() != YOUTUBE_PACKAGE) return false
                    return performGlobalAction(GLOBAL_ACTION_BACK)
                }
            },
            logger = { event -> logFocusGuardEvent(event) },
        )
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
        exitController.onShortsDetected()
        showOverlay(settings)
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        mainHandler.removeCallbacksAndMessages(null)
        dismissOverlay()
        super.onDestroy()
    }

    // --- Detection ---

    private fun detectShorts(event: AccessibilityEvent): Boolean {
        val className = event.className?.toString() ?: ""
        val root = rootInActiveWindow

        if (root != null && root.packageName?.toString() == YOUTUBE_PACKAGE) {
            if (isYoutubeHomeSelected(root)) {
                return false
            }
        }

        if (FocusGuardShortsSurfaceMatcher.isShortsClassName(className)) {
            Log.d(TAG, "Shorts hit via className=$className")
            return true
        }

        if (root == null || root.packageName?.toString() != YOUTUBE_PACKAGE) return false

        if (isYoutubeShortsSurface(root)) {
            Log.d(TAG, "Shorts hit via selected tab/watch surface")
            return true
        }
        return false
    }

    private fun findShortsWatchViewId(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > MAX_NODE_SEARCH_DEPTH) return false
        if (FocusGuardShortsSurfaceMatcher.isShortsWatchViewId(node.viewIdResourceName)) {
            return true
        }
        for (i in 0 until node.childCount) {
            if (findShortsWatchViewId(node.getChild(i), depth + 1)) return true
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
                tempAllowMinutes = sanitizeTempAllowMinutes(
                    json.optInt("tempAllowMinutes", 10),
                ),
                quickAllowEnabled = json.optBoolean("quickAllowEnabled", false),
            )
        } catch (_: Throwable) {
            null
        }
    }

    private fun sanitizeTempAllowMinutes(raw: Int): Int {
        return if (TEMP_ALLOW_OPTIONS.contains(raw)) raw else 10
    }

    private fun isTempAllowed(now: Long): Boolean {
        val prefs = getSharedPreferences(FocusGuardChannel.NATIVE_PREFS, Context.MODE_PRIVATE)
        val expiry = prefs.getLong(FocusGuardChannel.KEY_TEMP_ALLOW_EXPIRY, 0L)
        return expiry > now
    }

    private fun setTempAllow(minutes: Int) {
        val safeMinutes = sanitizeTempAllowMinutes(minutes)
        val prefs = getSharedPreferences(FocusGuardChannel.NATIVE_PREFS, Context.MODE_PRIVATE)
        val expiry = System.currentTimeMillis() + safeMinutes * 60_000L
        prefs.edit().putLong(FocusGuardChannel.KEY_TEMP_ALLOW_EXPIRY, expiry).apply()
        Log.d(TAG, "Temp allow set for $safeMinutes minutes")
    }

    private fun clearTempAllow(reason: String) {
        val prefs = getSharedPreferences(FocusGuardChannel.NATIVE_PREFS, Context.MODE_PRIVATE)
        prefs.edit().remove(FocusGuardChannel.KEY_TEMP_ALLOW_EXPIRY).apply()
        Log.d(TAG, "Temp allow revoked due to $reason")
    }

    // --- Overlay ---

    private fun showOverlay(settings: NativeSettings) {
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
            tempAllowMinutes = settings.tempAllowMinutes,
            quickAllowEnabled = settings.quickAllowEnabled,
            onBackToYoutubeHome = {
                lastActionTime = System.currentTimeMillis()
                val outcome = exitController.onUserExitTap()
                when (outcome) {
                    FocusGuardExitOutcome.CLICKED_HOME_TAB,
                    FocusGuardExitOutcome.USED_BACK_FALLBACK -> {
                        scheduleExitValidation(1, EXIT_CHECK_DELAY_MS)
                    }
                    FocusGuardExitOutcome.FAILED_NO_ACTION,
                    FocusGuardExitOutcome.EXIT_IN_PROGRESS -> Unit
                }
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

    private fun findYoutubeHomeTab(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        val screenHeight = resources.displayMetrics.heightPixels
        return findYoutubeHomeTab(root, 0, screenHeight)
    }

    private fun findYoutubeHomeTab(
        node: AccessibilityNodeInfo?,
        depth: Int,
        screenHeight: Int,
    ): AccessibilityNodeInfo? {
        if (node == null || depth > MAX_NODE_SEARCH_DEPTH) return null

        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        if (FocusGuardHomeTabMatcher.isBottomNavigationRegion(
                bounds.top,
                bounds.bottom,
                screenHeight,
            )
        ) {
            val clickableTarget = findClickableAncestorOrSelf(node)
            val probe = FocusGuardHomeTabProbe(
                text = node.text?.toString(),
                contentDescription = node.contentDescription?.toString(),
                viewIdResourceName = node.viewIdResourceName,
                selected = node.isSelected,
                visibleToUser = node.isVisibleToUser,
                enabled = node.isEnabled,
                clickableTargetAvailable = clickableTarget != null,
                top = bounds.top,
                bottom = bounds.bottom,
                screenHeight = screenHeight,
            )
            if (FocusGuardHomeTabMatcher.isHomeTabCandidate(probe)) {
                return clickableTarget
            }
        }

        for (i in 0 until node.childCount) {
            val match = findYoutubeHomeTab(node.getChild(i), depth + 1, screenHeight)
            if (match != null) return match
        }
        return null
    }

    private fun isYoutubeHomeSelected(root: AccessibilityNodeInfo): Boolean {
        val screenHeight = resources.displayMetrics.heightPixels
        return findSelectedYoutubeHomeTab(root, 0, screenHeight)
    }

    private fun findSelectedYoutubeHomeTab(
        node: AccessibilityNodeInfo?,
        depth: Int,
        screenHeight: Int,
    ): Boolean {
        if (node == null || depth > MAX_NODE_SEARCH_DEPTH) return false

        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        val clickableTarget = findClickableAncestorOrSelf(node)
        val probe = FocusGuardHomeTabProbe(
            text = node.text?.toString(),
            contentDescription = node.contentDescription?.toString(),
            viewIdResourceName = node.viewIdResourceName,
            selected = node.isSelected,
            visibleToUser = node.isVisibleToUser,
            enabled = node.isEnabled,
            clickableTargetAvailable = clickableTarget != null,
            top = bounds.top,
            bottom = bounds.bottom,
            screenHeight = screenHeight,
        )
        if (FocusGuardHomeTabMatcher.isSelectedHomeTabCandidate(probe)) {
            return true
        }

        for (i in 0 until node.childCount) {
            if (findSelectedYoutubeHomeTab(node.getChild(i), depth + 1, screenHeight)) {
                return true
            }
        }
        return false
    }

    private fun isYoutubeShortsSurface(root: AccessibilityNodeInfo): Boolean {
        if (findSelectedYoutubeShortsTab(root, 0, resources.displayMetrics.heightPixels)) {
            return true
        }
        return findShortsWatchViewId(root, 0)
    }

    private fun findSelectedYoutubeShortsTab(
        node: AccessibilityNodeInfo?,
        depth: Int,
        screenHeight: Int,
    ): Boolean {
        if (node == null || depth > MAX_NODE_SEARCH_DEPTH) return false

        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        val probe = FocusGuardShortsTabProbe(
            text = node.text?.toString(),
            contentDescription = node.contentDescription?.toString(),
            viewIdResourceName = node.viewIdResourceName,
            selected = node.isSelected,
            visibleToUser = node.isVisibleToUser,
            enabled = node.isEnabled,
            top = bounds.top,
            bottom = bounds.bottom,
            screenHeight = screenHeight,
        )
        if (FocusGuardShortsSurfaceMatcher.isSelectedShortsTabCandidate(probe)) {
            return true
        }

        for (i in 0 until node.childCount) {
            if (findSelectedYoutubeShortsTab(node.getChild(i), depth + 1, screenHeight)) {
                return true
            }
        }
        return false
    }

    private fun findClickableAncestorOrSelf(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        var current: AccessibilityNodeInfo? = node
        var hops = 0
        while (current != null && hops <= 4) {
            if (current.isVisibleToUser && current.isEnabled && current.isClickable) {
                return current
            }
            current = current.parent
            hops++
        }
        return null
    }

    private fun scheduleExitValidation(attempt: Int, delayMs: Long) {
        mainHandler.postDelayed(
            { validateExitAttempt(attempt) },
            delayMs,
        )
    }

    private fun validateExitAttempt(attempt: Int) {
        if (overlayView == null) return
        if (!isCurrentYoutubeShorts()) {
            dismissOverlay()
            return
        }
        if (attempt >= EXIT_CHECK_ATTEMPTS) {
            exitController.onExitValidationFinished()
            return
        }
        scheduleExitValidation(attempt + 1, EXIT_RECHECK_DELAY_MS)
    }

    private fun isCurrentYoutubeShorts(): Boolean {
        val root = rootInActiveWindow ?: return false
        if (root.packageName?.toString() != YOUTUBE_PACKAGE) return false
        val className = root.className?.toString() ?: ""
        if (isYoutubeHomeSelected(root)) return false
        if (FocusGuardShortsSurfaceMatcher.isShortsClassName(className)) {
            return true
        }
        return isYoutubeShortsSurface(root)
    }

    private fun logFocusGuardEvent(event: FocusGuardExitLogEvent) {
        Log.d(TAG, event.value)
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
        exitController.onExitValidationFinished()
        blockCountGate.onOverlayDismissed()
    }

}
