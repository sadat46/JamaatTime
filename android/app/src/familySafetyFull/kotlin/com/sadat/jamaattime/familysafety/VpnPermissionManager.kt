package com.sadat.jamaattime.familysafety

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import io.flutter.plugin.common.MethodChannel

class VpnPermissionManager(private val activity: Activity) {

    companion object {
        const val REQUEST_CODE = 7525
    }

    private var pendingResult: MethodChannel.Result? = null

    fun isPrepared(): Boolean {
        return VpnService.prepare(activity.applicationContext) == null
    }

    fun requestPermission(result: MethodChannel.Result) {
        if (isPrepared()) {
            result.success(true)
            return
        }

        if (pendingResult != null) {
            result.error(
                "vpn_permission_in_progress",
                "VPN permission request is already in progress.",
                null,
            )
            return
        }

        val intent = VpnService.prepare(activity.applicationContext)
        if (intent == null) {
            result.success(true)
            return
        }

        pendingResult = result
        try {
            activity.startActivityForResult(intent, REQUEST_CODE)
        } catch (_: Exception) {
            pendingResult = null
            result.success(false)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) {
            return false
        }

        val result = pendingResult
        pendingResult = null
        result?.success(resultCode == Activity.RESULT_OK || isPrepared())
        return true
    }
}
