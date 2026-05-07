package com.sadat.jamaattime.focusguard

internal data class FocusGuardHomeTabProbe(
    val text: String?,
    val contentDescription: String?,
    val viewIdResourceName: String?,
    val visibleToUser: Boolean,
    val enabled: Boolean,
    val clickableTargetAvailable: Boolean,
    val top: Int,
    val bottom: Int,
    val screenHeight: Int,
)

internal object FocusGuardHomeTabMatcher {
    fun isHomeTabCandidate(probe: FocusGuardHomeTabProbe): Boolean {
        if (!probe.visibleToUser || !probe.enabled || !probe.clickableTargetAvailable) {
            return false
        }
        if (!isBottomNavigationRegion(probe.top, probe.bottom, probe.screenHeight)) {
            return false
        }
        return labelLooksLikeHome(probe.text) ||
                labelLooksLikeHome(probe.contentDescription) ||
                viewIdLooksLikeHome(probe.viewIdResourceName)
    }

    fun isBottomNavigationRegion(top: Int, bottom: Int, screenHeight: Int): Boolean {
        if (screenHeight <= 0) return true
        val minTop = (screenHeight * 0.45f).toInt()
        val minBottom = (screenHeight * 0.60f).toInt()
        return top >= minTop && bottom >= minBottom
    }

    private fun labelLooksLikeHome(raw: String?): Boolean {
        val label = raw?.trim()?.lowercase() ?: return false
        if (label == "home" || label == "হোম" || label == "মূলপাতা") return true
        if (label.startsWith("home,") || label.startsWith("home tab")) return true
        if (label.contains("home selected") || label.contains("home, selected")) return true
        return label.contains("হোম")
    }

    private fun viewIdLooksLikeHome(raw: String?): Boolean {
        val id = raw?.lowercase() ?: return false
        if (!id.contains("home")) return false
        return id.contains("bottom") ||
                id.contains("bar") ||
                id.contains("pivot") ||
                id.contains("tab") ||
                id.contains("navigation") ||
                id.endsWith("/home")
    }
}
