package com.sadat.jamaattime.familysafety.vpn

import android.content.Intent
import android.net.VpnService

class FamilySafetyVpnService : VpnService() {

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        VpnStatusRepository(applicationContext).markStopped()
        stopSelf(startId)
        return START_NOT_STICKY
    }
}
