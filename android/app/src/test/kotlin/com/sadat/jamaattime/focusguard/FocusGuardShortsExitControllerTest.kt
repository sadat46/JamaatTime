package com.sadat.jamaattime.focusguard

import org.junit.Assert.assertEquals
import org.junit.Test

class FocusGuardShortsExitControllerTest {

    @Test fun shortsDetected_logsDetectedEvent() {
        val logs = mutableListOf<FocusGuardExitLogEvent>()
        val controller = FocusGuardShortsExitController(
            actions = FakeActions(homeClickResult = null, backResult = false),
            logger = { logs.add(it) },
        )

        controller.onShortsDetected()

        assertEquals(listOf(FocusGuardExitLogEvent.DETECTED_SHORTS), logs)
    }

    @Test fun userExitTap_prefersHomeTabClick() {
        val logs = mutableListOf<FocusGuardExitLogEvent>()
        val actions = FakeActions(homeClickResult = true, backResult = true)
        val controller = FocusGuardShortsExitController(
            actions = actions,
            logger = { logs.add(it) },
        )

        val outcome = controller.onUserExitTap()

        assertEquals(FocusGuardExitOutcome.CLICKED_HOME_TAB, outcome)
        assertEquals(1, actions.homeAttempts)
        assertEquals(0, actions.backAttempts)
        assertEquals(listOf(FocusGuardExitLogEvent.CLICKED_HOME_TAB), logs)
    }

    @Test fun userExitTap_usesOneBackFallbackWhenHomeTabAbsent() {
        val logs = mutableListOf<FocusGuardExitLogEvent>()
        val actions = FakeActions(homeClickResult = null, backResult = true)
        val controller = FocusGuardShortsExitController(
            actions = actions,
            logger = { logs.add(it) },
        )

        val outcome = controller.onUserExitTap()

        assertEquals(FocusGuardExitOutcome.USED_BACK_FALLBACK, outcome)
        assertEquals(1, actions.homeAttempts)
        assertEquals(1, actions.backAttempts)
        assertEquals(listOf(FocusGuardExitLogEvent.USED_BACK_FALLBACK), logs)
    }

    @Test fun userExitTap_doesNotFallbackWhenHomeTabClickFails() {
        val logs = mutableListOf<FocusGuardExitLogEvent>()
        val actions = FakeActions(homeClickResult = false, backResult = true)
        val controller = FocusGuardShortsExitController(
            actions = actions,
            logger = { logs.add(it) },
        )

        val outcome = controller.onUserExitTap()

        assertEquals(FocusGuardExitOutcome.FAILED_NO_ACTION, outcome)
        assertEquals(1, actions.homeAttempts)
        assertEquals(0, actions.backAttempts)
        assertEquals(listOf(FocusGuardExitLogEvent.FAILED_NO_ACTION), logs)
    }

    @Test fun userExitTap_logsFailedWhenNoActionRuns() {
        val logs = mutableListOf<FocusGuardExitLogEvent>()
        val actions = FakeActions(homeClickResult = null, backResult = false)
        val controller = FocusGuardShortsExitController(
            actions = actions,
            logger = { logs.add(it) },
        )

        val outcome = controller.onUserExitTap()

        assertEquals(FocusGuardExitOutcome.FAILED_NO_ACTION, outcome)
        assertEquals(1, actions.homeAttempts)
        assertEquals(1, actions.backAttempts)
        assertEquals(listOf(FocusGuardExitLogEvent.FAILED_NO_ACTION), logs)
    }

    private class FakeActions(
        private val homeClickResult: Boolean?,
        private val backResult: Boolean,
    ) : FocusGuardShortsExitController.Actions {
        var homeAttempts = 0
            private set
        var backAttempts = 0
            private set

        override fun clickYoutubeHomeTab(): Boolean? {
            homeAttempts++
            return homeClickResult
        }

        override fun performSingleBackFallback(): Boolean {
            backAttempts++
            return backResult
        }
    }
}
