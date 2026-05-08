package com.sadat.jamaattime.autovibration

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Thin wrapper over AlarmManager that schedules ringer-mode start/end events
 * around each jamaat time. Two alarms per prayer; stable request codes so a
 * subsequent schedule() call replaces the prior set.
 */
object AutoVibrationScheduler {
    private const val TAG = "AutoVibrationScheduler"

    const val ACTION_START = "com.sadat.jamaattime.autovibration.START"
    const val ACTION_END = "com.sadat.jamaattime.autovibration.END"
    const val EXTRA_PRAYER = "prayer"

    private val PRAYER_ORDER = listOf("fajr", "dhuhr", "asr", "maghrib", "isha")
    private const val REQ_BASE = 3100

    data class Window(val prayer: String, val startEpoch: Long, val endEpoch: Long)

    fun schedule(context: Context, windows: List<Window>) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        cancelAll(context, am)

        val now = System.currentTimeMillis()
        for (w in windows) {
            val idx = PRAYER_ORDER.indexOf(w.prayer.lowercase())
            if (idx < 0) {
                Log.w(TAG, "skip unknown prayer=${w.prayer}")
                continue
            }
            if (w.endEpoch <= now) continue

            // Schedule START unless it has already passed (we still want END to
            // restore ringer if app was opened mid-window).
            if (w.startEpoch > now) {
                setAlarm(context, am, idx, ACTION_START, w.prayer, w.startEpoch)
            }
            setAlarm(context, am, idx, ACTION_END, w.prayer, w.endEpoch)
        }
    }

    fun cancelAll(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        cancelAll(context, am)
    }

    private fun cancelAll(context: Context, am: AlarmManager) {
        for (idx in PRAYER_ORDER.indices) {
            am.cancel(buildPi(context, idx, ACTION_START, PRAYER_ORDER[idx]))
            am.cancel(buildPi(context, idx, ACTION_END, PRAYER_ORDER[idx]))
        }
    }

    private fun setAlarm(
        context: Context,
        am: AlarmManager,
        idx: Int,
        action: String,
        prayer: String,
        fireAt: Long,
    ) {
        val pi = buildPi(context, idx, action, prayer)
        val canExact =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()
        val mode = try {
            if (canExact) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pi)
                "exact"
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pi)
                "inexact"
            }
        } catch (_: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pi)
            "inexact_fallback"
        }
        Log.i(TAG, "scheduled action=$action prayer=$prayer fireAt=$fireAt mode=$mode")
    }

    private fun buildPi(
        context: Context,
        idx: Int,
        action: String,
        prayer: String,
    ): PendingIntent {
        val req = REQ_BASE + idx * 2 + if (action == ACTION_START) 0 else 1
        val intent = Intent(context, AutoVibrationReceiver::class.java)
            .setAction(action)
            .putExtra(EXTRA_PRAYER, prayer)
        return PendingIntent.getBroadcast(
            context,
            req,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
