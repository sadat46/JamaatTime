package com.sadat.jamaattime.autovibration

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.util.Log

class AutoVibrationReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AutoVibrationReceiver"
        private const val PREFS = "auto_vibration_state"
        private fun snapshotKey(prayer: String) = "snapshot_${prayer.lowercase()}"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        val prayer = intent.getStringExtra(AutoVibrationScheduler.EXTRA_PRAYER) ?: "unknown"

        val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        if (!hasDndAccessIfRequired(context, audio)) {
            Log.w(TAG, "DND access missing; no-op for action=$action prayer=$prayer")
            return
        }

        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        when (action) {
            AutoVibrationScheduler.ACTION_START -> {
                val current = audio.ringerMode
                prefs.edit().putInt(snapshotKey(prayer), current).apply()
                try {
                    audio.ringerMode = AudioManager.RINGER_MODE_VIBRATE
                    Log.i(TAG, "START prayer=$prayer prev=$current -> VIBRATE")
                } catch (e: SecurityException) {
                    Log.w(TAG, "START prayer=$prayer denied: ${e.message}")
                }
            }
            AutoVibrationScheduler.ACTION_END -> {
                val saved = prefs.getInt(snapshotKey(prayer), -1)
                prefs.edit().remove(snapshotKey(prayer)).apply()
                if (saved < 0) {
                    Log.i(TAG, "END prayer=$prayer no snapshot; leaving ringer as-is")
                    return
                }
                try {
                    audio.ringerMode = saved
                    Log.i(TAG, "END prayer=$prayer restored=$saved")
                } catch (e: SecurityException) {
                    Log.w(TAG, "END prayer=$prayer denied: ${e.message}")
                }
            }
        }
    }

    /**
     * On Android 7+ (N), changing ringer mode TO/FROM SILENT requires DND access.
     * Switching between NORMAL and VIBRATE may also be gated on some OEMs, so we
     * require it across the board on M+.
     */
    private fun hasDndAccessIfRequired(context: Context, audio: AudioManager): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return false
        return nm.isNotificationPolicyAccessGranted
    }
}
