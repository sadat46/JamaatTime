package com.sadat.jamaattime.familysafety

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import com.sadat.jamaattime.familysafety.vpn.ActivitySummaryWriter
import com.sadat.jamaattime.familysafety.vpn.FamilySafetyVpnService
import com.sadat.jamaattime.familysafety.vpn.VpnStatusRepository
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class FamilySafetyChannel(messenger: BinaryMessenger, private val activity: Activity) {

    companion object {
        const val CHANNEL_NAME = "jamaat_time/family_safety"
    }

    private val context: Context = activity.applicationContext
    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val vpnPermissionManager = VpnPermissionManager(activity)
    private val vpnStatusRepository = VpnStatusRepository(context)
    private val activitySummaryWriter = ActivitySummaryWriter(context)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPrivateDnsState" -> result.success(getPrivateDnsState())
                "isVpnPrepared" -> result.success(vpnPermissionManager.isPrepared())
                "requestVpnPermission" -> vpnPermissionManager.requestPermission(result)
                "getVpnStatus" -> result.success(
                    vpnStatusRepository.getStatus(vpnPermissionManager.isPrepared())
                )
                "startWebsiteProtection" -> result.success(startWebsiteProtection())
                "stopWebsiteProtection" -> result.success(stopWebsiteProtection())
                "getActivitySummary" -> {
                    val rangeDays = (call.argument<Int>("rangeDays") ?: 30).coerceIn(1, 365)
                    result.success(activitySummaryWriter.readRange(rangeDays))
                }
                "clearActivitySummary" -> {
                    activitySummaryWriter.clear()
                    result.success(true)
                }
                "openNetworkSettings" -> {
                    openNetworkSettings()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startWebsiteProtection(): Boolean {
        if (!vpnPermissionManager.isPrepared()) return false
        val intent = Intent(context, FamilySafetyVpnService::class.java)
        return try {
            vpnStatusRepository.markStarting()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, intent)
            } else {
                context.startService(intent)
            }
            true
        } catch (e: Exception) {
            vpnStatusRepository.markError(e.message)
            false
        }
    }

    private fun stopWebsiteProtection(): Boolean {
        val intent = Intent(context, FamilySafetyVpnService::class.java).apply {
            action = FamilySafetyVpnService.ACTION_STOP
        }
        return try {
            context.startService(intent)
            true
        } catch (_: Exception) {
            false
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
        return vpnPermissionManager.onActivityResult(requestCode, resultCode, data)
    }
}
