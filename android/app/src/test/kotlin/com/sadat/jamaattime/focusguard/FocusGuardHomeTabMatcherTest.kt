package com.sadat.jamaattime.focusguard

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FocusGuardHomeTabMatcherTest {

    @Test fun bottomVisibleClickableHomeLabel_isCandidate() {
        val probe = baseProbe(text = "Home")

        assertTrue(FocusGuardHomeTabMatcher.isHomeTabCandidate(probe))
    }

    @Test fun bottomVisibleClickableBanglaHomeLabel_isCandidate() {
        val probe = baseProbe(contentDescription = "হোম")

        assertTrue(FocusGuardHomeTabMatcher.isHomeTabCandidate(probe))
    }

    @Test fun bottomVisibleClickableHomeViewId_isCandidate() {
        val probe = baseProbe(
            text = null,
            viewIdResourceName = "com.google.android.youtube:id/bottom_navigation_home",
        )

        assertTrue(FocusGuardHomeTabMatcher.isHomeTabCandidate(probe))
    }

    @Test fun selectedBottomHomeTab_isSelectedCandidate() {
        val probe = baseProbe(text = "Home", selected = true)

        assertTrue(FocusGuardHomeTabMatcher.isSelectedHomeTabCandidate(probe))
    }

    @Test fun unselectedBottomHomeTab_isNotSelectedCandidate() {
        val probe = baseProbe(text = "Home", selected = false)

        assertFalse(FocusGuardHomeTabMatcher.isSelectedHomeTabCandidate(probe))
    }

    @Test fun topHomeLabel_isNotCandidate() {
        val probe = baseProbe(text = "Home", top = 120, bottom = 220)

        assertFalse(FocusGuardHomeTabMatcher.isHomeTabCandidate(probe))
    }

    @Test fun homeLabelWithoutClickableTarget_isNotCandidate() {
        val probe = baseProbe(text = "Home", clickableTargetAvailable = false)

        assertFalse(FocusGuardHomeTabMatcher.isHomeTabCandidate(probe))
    }

    @Test fun bottomSubscriptionsLabel_isNotCandidate() {
        val probe = baseProbe(text = "Subscriptions")

        assertFalse(FocusGuardHomeTabMatcher.isHomeTabCandidate(probe))
    }

    private fun baseProbe(
        text: String? = null,
        contentDescription: String? = null,
        viewIdResourceName: String? = null,
        selected: Boolean = false,
        visibleToUser: Boolean = true,
        enabled: Boolean = true,
        clickableTargetAvailable: Boolean = true,
        top: Int = 1780,
        bottom: Int = 1880,
        screenHeight: Int = 2000,
    ) = FocusGuardHomeTabProbe(
        text = text,
        contentDescription = contentDescription,
        viewIdResourceName = viewIdResourceName,
        selected = selected,
        visibleToUser = visibleToUser,
        enabled = enabled,
        clickableTargetAvailable = clickableTargetAvailable,
        top = top,
        bottom = bottom,
        screenHeight = screenHeight,
    )
}
