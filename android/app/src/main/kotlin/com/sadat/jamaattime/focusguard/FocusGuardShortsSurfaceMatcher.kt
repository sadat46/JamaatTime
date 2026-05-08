package com.sadat.jamaattime.focusguard

internal data class FocusGuardShortsTabProbe(
    val text: String?,
    val contentDescription: String?,
    val viewIdResourceName: String?,
    val selected: Boolean,
    val visibleToUser: Boolean,
    val enabled: Boolean,
    val top: Int,
    val bottom: Int,
    val screenHeight: Int,
)

internal object FocusGuardShortsSurfaceMatcher {
    fun isShortsClassName(raw: String?): Boolean {
        val className = raw ?: return false
        return className.contains("Shorts", ignoreCase = true) ||
                className.contains("ReelWatch", ignoreCase = true)
    }

    fun isShortsWatchViewId(raw: String?): Boolean {
        val id = raw?.lowercase() ?: return false
        return id.contains("reel_watch") ||
                id.contains("shorts_watch") ||
                id.contains("reel_player") ||
                id.contains("shorts_player") ||
                id.contains("shorts_fragment")
    }

    fun isSelectedShortsTabCandidate(probe: FocusGuardShortsTabProbe): Boolean {
        if (!probe.visibleToUser || !probe.enabled) return false
        if (!probe.selected && !selectedLabelLooksLikeShorts(probe.text) &&
            !selectedLabelLooksLikeShorts(probe.contentDescription)
        ) {
            return false
        }
        if (!FocusGuardHomeTabMatcher.isBottomNavigationRegion(
                probe.top,
                probe.bottom,
                probe.screenHeight,
            )
        ) {
            return false
        }
        return labelLooksLikeShorts(probe.text) ||
                labelLooksLikeShorts(probe.contentDescription) ||
                viewIdLooksLikeShortsTab(probe.viewIdResourceName)
    }

    private fun labelLooksLikeShorts(raw: String?): Boolean {
        val label = raw?.trim()?.lowercase() ?: return false
        if (label == "shorts") return true
        if (label.startsWith("shorts,") || label.startsWith("shorts tab")) return true
        if (label.contains("shorts selected") || label.contains("shorts, selected")) return true
        return false
    }

    private fun selectedLabelLooksLikeShorts(raw: String?): Boolean {
        val label = raw?.trim()?.lowercase() ?: return false
        if (!labelLooksLikeShorts(label)) return false
        return label.contains("selected")
    }

    private fun viewIdLooksLikeShortsTab(raw: String?): Boolean {
        val id = raw?.lowercase() ?: return false
        if (!id.contains("shorts")) return false
        return id.contains("bottom") ||
                id.contains("bar") ||
                id.contains("pivot") ||
                id.contains("tab") ||
                id.contains("navigation")
    }
}
