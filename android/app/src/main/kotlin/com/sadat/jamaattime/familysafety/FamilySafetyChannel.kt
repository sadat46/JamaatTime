package com.sadat.jamaattime.familysafety

import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class FamilySafetyChannel(messenger: BinaryMessenger, private val context: Context) {

    companion object {
        const val CHANNEL_NAME = "jamaat_time/family_safety"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPrivateDnsState" -> result.success(getPrivateDnsState())
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
}
