package com.sadat.jamaattime.familysafety

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class FamilySafetyChannel(messenger: BinaryMessenger, private val activity: Activity) {

    companion object {
        const val CHANNEL_NAME = "jamaat_time/family_safety"
    }

    private val context: Context = activity.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPrivateDnsState" -> result.success(getPrivateDnsState())
                "isVpnPrepared" -> result.success(false)
                "requestVpnPermission" -> result.success(false)
                "getVpnStatus" -> result.success(
                    mapOf(
                        "prepared" to false,
                        "running" to false,
                        "supported" to false,
                    )
                )
                "startWebsiteProtection" -> result.success(false)
                "stopWebsiteProtection" -> result.success(false)
                "getActivitySummary" -> result.success(emptyList<Map<String, Any>>())
                "clearActivitySummary" -> result.success(true)
                "openNetworkSettings" -> {
                    openNetworkSettings()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getPrivateDnsState(): Map<String, String?> {
        val resolver = context.contentResolver
        val mode = Settings.Global.getString(resolver, "private_dns_mode") ?: "unknown"
        val host = Settings.Global.getString(resolver, "private_dns_specifier")
        return mapOf(
            "mode" to mode,
            "host" to host,
        )
    }

    private fun openNetworkSettings() {
        val intent = Intent(Settings.ACTION_WIRELESS_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (_: Exception) {
            val fallback = Intent(Settings.ACTION_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(fallback)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return false
    }
}
