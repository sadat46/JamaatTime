package com.sadat.jamaattime.autovibration

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AutoVibrationPlugin(messenger: BinaryMessenger, private val context: Context) {

    companion object {
        const val CHANNEL_NAME = "jamaat_time/auto_vibration"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasDndAccess" -> result.success(hasDndAccess())
            "openDndSettings" -> {
                openDndSettings()
                result.success(null)
            }
            "schedule" -> {
                @Suppress("UNCHECKED_CAST")
                val raw = call.argument<List<Map<String, Any?>>>("windows") ?: emptyList()
                val windows = raw.mapNotNull { m ->
                    val prayer = m["prayer"] as? String ?: return@mapNotNull null
                    val start = (m["startEpoch"] as? Number)?.toLong() ?: return@mapNotNull null
                    val end = (m["endEpoch"] as? Number)?.toLong() ?: return@mapNotNull null
                    AutoVibrationScheduler.Window(prayer, start, end)
                }
                AutoVibrationScheduler.schedule(context, windows)
                result.success(null)
            }
            "cancelAll" -> {
                AutoVibrationScheduler.cancelAll(context)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun hasDndAccess(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return false
        return nm.isNotificationPolicyAccessGranted
    }

    private fun openDndSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (_: Exception) {
            // Some OEMs don't expose this screen — fall back to app details.
            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(android.net.Uri.parse("package:${context.packageName}"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(fallback)
        }
    }
}
