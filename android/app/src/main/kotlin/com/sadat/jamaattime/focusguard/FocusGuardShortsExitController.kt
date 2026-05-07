package com.sadat.jamaattime.focusguard

internal enum class FocusGuardExitLogEvent(val value: String) {
    DETECTED_SHORTS("detected_shorts"),
    CLICKED_HOME_TAB("clicked_home_tab"),
    USED_BACK_FALLBACK("used_back_fallback"),
    FAILED_NO_ACTION("failed_no_action"),
}

internal enum class FocusGuardExitOutcome(val logEvent: FocusGuardExitLogEvent) {
    CLICKED_HOME_TAB(FocusGuardExitLogEvent.CLICKED_HOME_TAB),
    USED_BACK_FALLBACK(FocusGuardExitLogEvent.USED_BACK_FALLBACK),
    FAILED_NO_ACTION(FocusGuardExitLogEvent.FAILED_NO_ACTION),
}

internal class FocusGuardShortsExitController(
    private val actions: Actions,
    private val logger: (FocusGuardExitLogEvent) -> Unit,
) {
    interface Actions {
        /**
         * Returns true when YouTube Home was found and clicked, false when it was
         * found but could not be clicked, and null when no safe Home tab exists.
         */
        fun clickYoutubeHomeTab(): Boolean?

        fun performSingleBackFallback(): Boolean
    }

    fun onShortsDetected() {
        logger(FocusGuardExitLogEvent.DETECTED_SHORTS)
    }

    fun onUserExitTap(): FocusGuardExitOutcome {
        val homeClicked = actions.clickYoutubeHomeTab()
        val outcome = when (homeClicked) {
            true -> FocusGuardExitOutcome.CLICKED_HOME_TAB
            false -> FocusGuardExitOutcome.FAILED_NO_ACTION
            null -> {
                if (actions.performSingleBackFallback()) {
                    FocusGuardExitOutcome.USED_BACK_FALLBACK
                } else {
                    FocusGuardExitOutcome.FAILED_NO_ACTION
                }
            }
        }
        logger(outcome.logEvent)
        return outcome
    }
}
