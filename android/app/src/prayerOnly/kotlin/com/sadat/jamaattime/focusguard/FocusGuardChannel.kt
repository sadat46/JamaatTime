package com.sadat.jamaattime.focusguard

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class FocusGuardChannel(messenger: BinaryMessenger, private val context: Context) {

    companion object {
        const val CHANNEL_NAME = "jamaat_time/focus_guard"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> result.success(false)
                "openAccessibilitySettings" -> result.success(null)
                "updateSettings" -> result.success(null)
                else -> result.notImplemented()
            }
        }
    }
}
