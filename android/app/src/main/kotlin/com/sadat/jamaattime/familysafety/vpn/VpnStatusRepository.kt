package com.sadat.jamaattime.familysafety.vpn

import android.content.Context

class VpnStatusRepository(context: Context) {

    companion object {
        private const val PREFS_NAME = "family_safety_vpn_status"
        private const val KEY_RUNNING = "running"
        private const val KEY_LAST_ERROR = "last_error"
    }

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun getStatus(prepared: Boolean): Map<String, Any?> {
        return mapOf(
            "prepared" to prepared,
            "running" to prefs.getBoolean(KEY_RUNNING, false),
            "lastError" to prefs.getString(KEY_LAST_ERROR, null),
        )
    }

    fun isRunning(): Boolean = prefs.getBoolean(KEY_RUNNING, false)

    fun markStarting() {
        prefs.edit()
            .putBoolean(KEY_RUNNING, false)
            .remove(KEY_LAST_ERROR)
            .apply()
    }

    fun markRunning() {
        prefs.edit()
            .putBoolean(KEY_RUNNING, true)
            .remove(KEY_LAST_ERROR)
            .apply()
    }

    fun markError(message: String?) {
        prefs.edit()
            .putBoolean(KEY_RUNNING, false)
            .putString(KEY_LAST_ERROR, message ?: "unknown_error")
            .apply()
    }

    fun markStopped() {
        prefs.edit()
            .putBoolean(KEY_RUNNING, false)
            .remove(KEY_LAST_ERROR)
            .apply()
    }
}
