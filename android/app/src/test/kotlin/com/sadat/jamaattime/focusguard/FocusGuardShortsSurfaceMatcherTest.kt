package com.sadat.jamaattime.focusguard

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FocusGuardShortsSurfaceMatcherTest {

    @Test fun reelWatchClassName_isShortsSurface() {
        assertTrue(
            FocusGuardShortsSurfaceMatcher.isShortsClassName(
                "com.google.android.apps.youtube.app.watchwhile.ReelWatchActivity",
            ),
        )
    }

    @Test fun selectedBottomShortsTab_isShortsSurface() {
        val probe = baseProbe(text = "Shorts", selected = true)

        assertTrue(FocusGuardShortsSurfaceMatcher.isSelectedShortsTabCandidate(probe))
    }

    @Test fun unselectedBottomShortsTab_isNotShortsSurface() {
        val probe = baseProbe(text = "Shorts", selected = false)

        assertFalse(FocusGuardShortsSurfaceMatcher.isSelectedShortsTabCandidate(probe))
    }

    @Test fun genericShortsShelfId_isNotWatchSurface() {
        assertFalse(
            FocusGuardShortsSurfaceMatcher.isShortsWatchViewId(
                "com.google.android.youtube:id/shorts_shelf",
            ),
        )
    }

    @Test fun shortsWatchId_isWatchSurface() {
        assertTrue(
            FocusGuardShortsSurfaceMatcher.isShortsWatchViewId(
                "com.google.android.youtube:id/reel_watch_fragment",
            ),
        )
    }

    @Test fun topSelectedShortsLabel_isNotShortsTab() {
        val probe = baseProbe(text = "Shorts", selected = true, top = 80, bottom = 180)

        assertFalse(FocusGuardShortsSurfaceMatcher.isSelectedShortsTabCandidate(probe))
    }

    private fun baseProbe(
        text: String? = null,
        contentDescription: String? = null,
        viewIdResourceName: String? = null,
        selected: Boolean = false,
        visibleToUser: Boolean = true,
        enabled: Boolean = true,
        top: Int = 1780,
        bottom: Int = 1880,
        screenHeight: Int = 2000,
    ) = FocusGuardShortsTabProbe(
        text = text,
        contentDescription = contentDescription,
        viewIdResourceName = viewIdResourceName,
        selected = selected,
        visibleToUser = visibleToUser,
        enabled = enabled,
        top = top,
        bottom = bottom,
        screenHeight = screenHeight,
    )
}
