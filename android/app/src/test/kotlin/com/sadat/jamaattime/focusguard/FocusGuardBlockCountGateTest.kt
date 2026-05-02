package com.sadat.jamaattime.focusguard

import com.sadat.jamaattime.familysafety.vpn.BlockCategory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FocusGuardBlockCountGateTest {

    @Test fun confirmedBlockOverlay_incrementsShortVideoCategoryOnce() {
        val increments = mutableListOf<BlockCategory>()
        val gate = FocusGuardBlockCountGate { category -> increments.add(category) }

        assertTrue(gate.onConfirmedBlockOverlayShown())

        assertEquals(listOf(BlockCategory.FOCUS_GUARD_SHORT_VIDEO), increments)
    }

    @Test fun sameOverlaySession_doesNotDuplicateRapidIncrements() {
        var increments = 0
        val gate = FocusGuardBlockCountGate { increments++ }

        assertTrue(gate.onConfirmedBlockOverlayShown())
        assertFalse(gate.onConfirmedBlockOverlayShown())
        assertFalse(gate.onConfirmedBlockOverlayShown())

        assertEquals(1, increments)
    }

    @Test fun dismissedOverlay_allowsNextConfirmedBlockToCount() {
        var increments = 0
        val gate = FocusGuardBlockCountGate { increments++ }

        assertTrue(gate.onConfirmedBlockOverlayShown())
        gate.onOverlayDismissed()
        assertTrue(gate.onConfirmedBlockOverlayShown())

        assertEquals(2, increments)
    }
}
