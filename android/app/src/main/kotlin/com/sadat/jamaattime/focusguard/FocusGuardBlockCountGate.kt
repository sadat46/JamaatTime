package com.sadat.jamaattime.focusguard

import com.sadat.jamaattime.familysafety.vpn.BlockCategory

internal class FocusGuardBlockCountGate(
    private val increment: (BlockCategory) -> Unit,
) {
    private var overlaySessionCounted = false

    fun onConfirmedBlockOverlayShown(): Boolean {
        if (overlaySessionCounted) return false
        overlaySessionCounted = true
        increment(BlockCategory.FOCUS_GUARD_SHORT_VIDEO)
        return true
    }

    fun onOverlayDismissed() {
        overlaySessionCounted = false
    }
}
