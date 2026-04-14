package com.example.jamaat_time.focusguard

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.text.TextUtils
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class FocusGuardChannel(messenger: BinaryMessenger, private val context: Context) {

    companion object {
        const val CHANNEL_NAME = "jamaat_time/focus_guard"
        const val NATIVE_PREFS = "focus_guard_native"
        const val KEY_SETTINGS_JSON = "focus_guard_native_settings"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())
                "isOverlayEnabled" -> result.success(Settings.canDrawOverlays(context))
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(null)
                }
                "openOverlaySettings" -> {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:${context.packageName}")
                    )
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(null)
                }
                "updateSettings" -> {
                    val json = call.argument<String>("json") ?: "{}"
                    val prefs = context.getSharedPreferences(NATIVE_PREFS, Context.MODE_PRIVATE)
                    prefs.edit().putString(KEY_SETTINGS_JSON, json).apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val expectedComponent = "${context.packageName}/${FocusGuardAccessibilityService::class.java.name}"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)
        while (colonSplitter.hasNext()) {
            val component = colonSplitter.next()
            if (component.equals(expectedComponent, ignoreCase = true)) {
                return true
            }
        }
        return false
    }
}
