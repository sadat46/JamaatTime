package com.sadat.jamaattime.focusguard

internal data class FocusGuardHomeTabProbe(
    val text: String?,
    val contentDescription: String?,
    val viewIdResourceName: String?,
    val selected: Boolean = false,
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

    fun isSelectedHomeTabCandidate(probe: FocusGuardHomeTabProbe): Boolean {
        if (!isHomeTabCandidate(probe)) return false
        return probe.selected ||
                selectedLabelLooksLikeHome(probe.text) ||
                selectedLabelLooksLikeHome(probe.contentDescription)
    }

    fun isBottomNavigationRegion(top: Int, bottom: Int, screenHeight: Int): Boolean {
        if (screenHeight <= 0) return true
        val minTop = (screenHeight * 0.45f).toInt()
        val minBottom = (screenHeight * 0.60f).toInt()
        return top >= minTop && bottom >= minBottom
    }

    private fun labelLooksLikeHome(raw: String?): Boolean {
        val label = raw?.trim()?.lowercase() ?: return false
        if (label == "home" ||
            label == "\u09B9\u09CB\u09AE" ||
            label == "\u09AE\u09C2\u09B2\u09AA\u09BE\u09A4\u09BE"
        ) {
            return true
        }
        if (label.startsWith("home,") || label.startsWith("home tab")) return true
        if (label.contains("home selected") || label.contains("home, selected")) return true
        return label.contains("\u09B9\u09CB\u09AE")
    }

    private fun selectedLabelLooksLikeHome(raw: String?): Boolean {
        val label = raw?.trim()?.lowercase() ?: return false
        if (!labelLooksLikeHome(label)) return false
        return label.contains("selected") ||
                label.contains("\u09A8\u09BF\u09B0\u09CD\u09AC\u09BE\u099A\u09BF\u09A4")
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
