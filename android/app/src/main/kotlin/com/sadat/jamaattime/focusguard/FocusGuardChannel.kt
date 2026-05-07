package com.sadat.jamaattime.focusguard

import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class FocusGuardChannel(messenger: BinaryMessenger, private val context: Context) {

    companion object {
        private const val TAG = "FocusGuardChannel"
        const val CHANNEL_NAME = "jamaat_time/focus_guard"
        const val NATIVE_PREFS = "focus_guard_native"
        const val KEY_SETTINGS_JSON = "focus_guard_native_settings"
        const val KEY_TEMP_ALLOW_EXPIRY = "focus_guard_temp_allow_expiry"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(null)
                }
                "updateSettings" -> {
                    val json = call.argument<String>("json") ?: "{}"
                    val prefs = context.getSharedPreferences(NATIVE_PREFS, Context.MODE_PRIVATE)
                    prefs.edit().putString(KEY_SETTINGS_JSON, json).apply()
                    revokeTempAllowIfNeeded(prefs, json)
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

    private fun revokeTempAllowIfNeeded(
        prefs: android.content.SharedPreferences,
        settingsJson: String,
    ) {
        try {
            val json = JSONObject(settingsJson)
            val enabled = json.optBoolean("enabled", false)
            val quickAllowEnabled = json.optBoolean("quickAllowEnabled", false)
            if (!enabled || !quickAllowEnabled) {
                prefs.edit().remove(KEY_TEMP_ALLOW_EXPIRY).apply()
                val reason = if (!enabled) "focus_guard_disabled" else "quick_bypass_disabled"
                Log.d(TAG, "Temp allow revoked due to $reason")
            }
        } catch (t: Throwable) {
            Log.w(TAG, "Skipping temp-allow revoke; invalid settings JSON", t)
        }
    }
}
