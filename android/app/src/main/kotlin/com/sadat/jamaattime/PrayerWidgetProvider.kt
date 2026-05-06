package com.sadat.jamaattime

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequest
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class PrayerWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "PrayerWidgetProvider"
        private const val MAINTENANCE_INTERVAL_HOURS = 6L

        const val ACTION_BOUNDARY_TICK = "com.sadat.jamaattime.action.BOUNDARY_TICK"

        // Single self-rearming alarm slot. Required architecture pins this
        // to 460100 so it cannot collide with notification IDs (1101-1105,
        // 2101-2105, 3101) and stays distinct from legacy widget slots.
        private const val REQ_BOUNDARY = 460100
        // Legacy slots kept only for cancellation on upgrade.
        private const val LEGACY_REQ_ALARM = 2
        private const val LEGACY_REQ_SELF_HEAL = 3
        private const val LEGACY_REQ_BOUNDARY_PRE_460100 = 10
        private const val LEGACY_REQ_JAMAAT_BOUNDARY = 11
        private const val LEGACY_REQ_JAMAAT_OVER = 12
        private const val LEGACY_REQ_MIDNIGHT = 13
        private const val LEGACY_REQ_PRAYER_EXPIRE_TICK = 14
        private const val LEGACY_REQ_JAMAAT_EXPIRE_TICK = 15

        private const val HOME_WIDGET_BACKGROUND_ACTION =
            "es.antonborri.home_widget.action.BACKGROUND"
        private const val HOME_WIDGET_BACKGROUND_RECEIVER =
            "es.antonborri.home_widget.HomeWidgetBackgroundReceiver"
        private const val BOUNDARY_URI = "homewidget://boundary"
        private const val REFRESH_URI = "homewidget://refresh"

        private const val PREFS_NAME = "HomeWidgetPreferences"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            val raw = readRawSchedule(prefs)
            val todayMidnight = WidgetState.localMidnightEpoch(now)

            val rolledOver = WidgetState.isNewLocalDay(raw.computeDay, todayMidnight)
            if (rolledOver) {
                logd("day rollover detected: lastComputeDay=${raw.computeDay} todayMidnight=$todayMidnight")
                triggerDartRefresh(context)
            }

            val state = WidgetState.compute(now, raw)
            val islamicDate = prefs.getString("islamic_date", "-") ?: "-"
            val location = prefs.getString("location", "-") ?: "-"
            val rowLabels = arrayOf(
                prefs.getString("row_label_1", "-") ?: "-",
                prefs.getString("row_label_2", "-") ?: "-",
                prefs.getString("row_label_3", "-") ?: "-",
                prefs.getString("row_label_4", "-") ?: "-",
            )
            val rowTimes = arrayOf(
                prefs.getString("row_time_1", "-") ?: "-",
                prefs.getString("row_time_2", "-") ?: "-",
                prefs.getString("row_time_3", "-") ?: "-",
                prefs.getString("row_time_4", "-") ?: "-",
            )

            for (id in appWidgetIds) {
                val views = RemoteViews(context.packageName, R.layout.prayer_widget)
                views.setTextViewText(R.id.prayer_name, state.prayerName)
                views.setTextViewText(R.id.prayer_time, state.prayerTimeLabel)
                views.setTextViewText(R.id.remaining_label, state.remainingLabel)
                views.setTextViewText(R.id.jamaat_label, state.jamaatLabel)

                if (state.countdownEpoch > now) {
                    val base = SystemClock.elapsedRealtime() + (state.countdownEpoch - now)
                    views.setChronometerCountDown(R.id.remaining_time, true)
                    views.setChronometer(R.id.remaining_time, base, null, true)
                } else {
                    views.setChronometer(R.id.remaining_time, 0L, null, false)
                    views.setTextViewText(R.id.remaining_time, "-")
                }

                if (state.jamaatCountdownEpoch > now) {
                    views.setViewVisibility(R.id.jamaat_label, View.VISIBLE)
                    views.setViewVisibility(R.id.jamaat_time, View.VISIBLE)
                    val base = SystemClock.elapsedRealtime() +
                        (state.jamaatCountdownEpoch - now)
                    views.setChronometerCountDown(R.id.jamaat_time, true)
                    views.setChronometer(R.id.jamaat_time, base, null, true)
                } else if (state.jamaatTextUsesTimeStyle) {
                    views.setViewVisibility(R.id.jamaat_label, View.VISIBLE)
                    views.setViewVisibility(R.id.jamaat_time, View.VISIBLE)
                    views.setChronometer(R.id.jamaat_time, 0L, null, false)
                    val text = if (state.jamaatValueText.isNotEmpty()) {
                        state.jamaatValueText
                    } else {
                        state.jamaatLabel
                    }
                    views.setTextViewText(R.id.jamaat_time, text)
                } else {
                    views.setViewVisibility(R.id.jamaat_label, View.VISIBLE)
                    views.setViewVisibility(R.id.jamaat_time, View.GONE)
                    views.setChronometer(R.id.jamaat_time, 0L, null, false)
                    views.setTextViewText(R.id.jamaat_time, "-")
                }

                views.setTextViewText(R.id.row_label_1, rowLabels[0])
                views.setTextViewText(R.id.row_time_1, rowTimes[0])
                views.setTextViewText(R.id.row_label_2, rowLabels[1])
                views.setTextViewText(R.id.row_time_2, rowTimes[1])
                views.setTextViewText(R.id.row_label_3, rowLabels[2])
                views.setTextViewText(R.id.row_time_3, rowTimes[2])
                views.setTextViewText(R.id.row_label_4, rowLabels[3])
                views.setTextViewText(R.id.row_time_4, rowTimes[3])
                views.setTextViewText(R.id.islamic_date, islamicDate)
                views.setTextViewText(R.id.location, location)

                val launchIntent = context.packageManager
                    .getLaunchIntentForPackage(context.packageName)
                if (launchIntent != null) {
                    val pi = PendingIntent.getActivity(
                        context,
                        0,
                        launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    )
                    views.setOnClickPendingIntent(R.id.widget_root, pi)
                }

                val refreshIntent = Intent(HOME_WIDGET_BACKGROUND_ACTION)
                    .setComponent(ComponentName(context, HOME_WIDGET_BACKGROUND_RECEIVER))
                    .setData(Uri.parse(REFRESH_URI))
                val refreshPi = PendingIntent.getBroadcast(
                    context,
                    1,
                    refreshIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.refresh_button, refreshPi)

                appWidgetManager.updateAppWidget(id, views)
            }

            val nextMidnight = WidgetState.nextLocalMidnightEpoch(now)
            val nextBoundary = WidgetState.nextBoundaryEpoch(now, raw, nextMidnight)
            Log.i(
                TAG,
                "JT_WIDGET recalculated now=$now nextBoundary=$nextBoundary " +
                    "countdownEpoch=${state.countdownEpoch}"
            )
            scheduleBoundaryAlarm(context, nextBoundary + 1000L)

            logd(
                "render now=$now currentPeriod=${raw.todayCurrentPeriod(now)} " +
                    "nextBoundary=$nextBoundary countdownEpoch=${state.countdownEpoch} " +
                    "jamaatState=${jamaatStateLabel(state)}"
            )
        } catch (t: Throwable) {
            Log.e(TAG, "Error updating widget", t)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action ?: return
        when (action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {
                logd("system broadcast: $action")
                cancelLegacyAlarms(context)
                triggerDartRefresh(context)
                updateAllWidgets(context)
            }
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED -> {
                logd("clock/zone broadcast: $action")
                triggerDartRefresh(context)
                updateAllWidgets(context)
            }
            ACTION_BOUNDARY_TICK -> {
                Log.i(TAG, "JT_WIDGET fired")
                logd("BOUNDARY_TICK received")
                updateAllWidgets(context)
            }
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        logd("widget enabled")
        try {
            val req = PeriodicWorkRequest.Builder(
                WidgetMaintenanceWorker::class.java,
                MAINTENANCE_INTERVAL_HOURS,
                TimeUnit.HOURS,
            ).build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "widget_maintenance",
                ExistingPeriodicWorkPolicy.KEEP,
                req,
            )
        } catch (t: Throwable) {
            Log.w(TAG, "Failed to enqueue maintenance worker", t)
        }
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelBoundaryAlarm(context)
        cancelLegacyAlarms(context)
        WorkManager.getInstance(context).cancelUniqueWork("widget_maintenance")
        logd("widget disabled")
    }

    // ------------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------------

    private fun updateAllWidgets(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(ComponentName(context, PrayerWidgetProvider::class.java))
        if (ids != null && ids.isNotEmpty()) {
            onUpdate(context, mgr, ids)
        }
    }

    private fun readRawSchedule(prefs: SharedPreferences): RawSchedule {
        val today = mapOf(
            "Fajr" to readEpoch(prefs, "epoch_fajr_today"),
            "Sunrise" to readEpoch(prefs, "epoch_sunrise_today"),
            "Dhuhr" to readEpoch(prefs, "epoch_dhuhr_today"),
            "Asr" to readEpoch(prefs, "epoch_asr_today"),
            "Maghrib" to readEpoch(prefs, "epoch_maghrib_today"),
            "Isha" to readEpoch(prefs, "epoch_isha_today"),
        )
        val jamaat = mapOf(
            "Fajr" to readEpoch(prefs, "jamaat_epoch_fajr_today"),
            "Dhuhr" to readEpoch(prefs, "jamaat_epoch_dhuhr_today"),
            "Asr" to readEpoch(prefs, "jamaat_epoch_asr_today"),
            "Maghrib" to readEpoch(prefs, "jamaat_epoch_maghrib_today"),
            "Isha" to readEpoch(prefs, "jamaat_epoch_isha_today"),
        )
        val localeCode = prefs.getString("locale_code", "en") ?: "en"
        val pattern = prefs.getString("time_format_pattern", "HH:mm") ?: "HH:mm"
        val loc = Localization(
            prayerName = mapOf(
                "Fajr" to (prefs.getString("loc_prayer_fajr", "Fajr") ?: "Fajr"),
                "Sunrise" to (prefs.getString("loc_prayer_sunrise", "Sunrise") ?: "Sunrise"),
                "Dhuhr" to (prefs.getString("loc_prayer_dhuhr", "Dhuhr") ?: "Dhuhr"),
                "Asr" to (prefs.getString("loc_prayer_asr", "Asr") ?: "Asr"),
                "Maghrib" to (prefs.getString("loc_prayer_maghrib", "Maghrib") ?: "Maghrib"),
                "Isha" to (prefs.getString("loc_prayer_isha", "Isha") ?: "Isha"),
            ),
            jamaatInSuffix = prefs.getString("loc_jamaat_in_suffix", "Jamaat in") ?: "Jamaat in",
            jamaatOngoing = prefs.getString("loc_jamaat_ongoing", "Jamaat ongoing") ?: "Jamaat ongoing",
            jamaatOver = prefs.getString("loc_jamaat_over", "Jamaat ended") ?: "Jamaat ended",
            jamaatNa = prefs.getString("loc_jamaat_na", "Jamaat N/A") ?: "Jamaat N/A",
            prayerEndsIn = prefs.getString("loc_prayer_ends_in", "Prayer ends in") ?: "Prayer ends in",
            nextPrayerInTemplate = prefs.getString("loc_next_prayer_in_template", "{0} in") ?: "{0} in",
            nextPrayerJamaatTemplate = prefs.getString(
                "loc_next_prayer_jamaat_template",
                "{0} Jamaat at {1}",
            ) ?: "{0} Jamaat at {1}",
            localeCode = localeCode,
        )
        return RawSchedule(
            today = today,
            fajrTomorrow = readEpoch(prefs, "epoch_fajr_tomorrow"),
            jamaatToday = jamaat,
            computeDay = readEpoch(prefs, "last_compute_day_epoch"),
            locale = loc,
            timeFormatPattern = pattern,
        )
    }

    private fun readEpoch(prefs: SharedPreferences, key: String): Long {
        val raw = prefs.all[key] ?: return 0L
        return when (raw) {
            is Long -> raw
            is Int -> raw.toLong()
            is String -> raw.toLongOrNull() ?: 0L
            else -> 0L
        }
    }

    private fun buildBoundaryIntent(ctx: Context, requestCode: Int): PendingIntent {
        val intent = Intent(ctx, PrayerWidgetProvider::class.java)
            .setAction(ACTION_BOUNDARY_TICK)
        return PendingIntent.getBroadcast(
            ctx,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun scheduleBoundaryAlarm(ctx: Context, fireAt: Long) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val pi = buildBoundaryIntent(ctx, REQ_BOUNDARY)
        val nowMs = System.currentTimeMillis()
        val deltaSec = ((fireAt - nowMs).coerceAtLeast(0L)) / 1000L
        var mode = "inexact"
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pi)
                mode = "exact"
                logd("alarm scheduled in ${deltaSec}s via exactIdle")
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pi)
                logd("alarm scheduled in ${deltaSec}s via inexactIdle")
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Exact alarm denied; falling back to inexact idle", e)
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pi)
            mode = "inexact"
        }
        Log.i(TAG, "JT_WIDGET scheduled fireAt=$fireAt deltaSec=$deltaSec mode=$mode req=$REQ_BOUNDARY")
    }

    private fun cancelBoundaryAlarm(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        am.cancel(buildBoundaryIntent(ctx, REQ_BOUNDARY))
    }

    private fun cancelLegacyAlarms(ctx: Context) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        // Cancel multi-alarm-scheme PIs from the prior build.
        am.cancel(buildBoundaryIntent(ctx, LEGACY_REQ_BOUNDARY_PRE_460100))
        am.cancel(buildBoundaryIntent(ctx, LEGACY_REQ_JAMAAT_BOUNDARY))
        am.cancel(buildBoundaryIntent(ctx, LEGACY_REQ_JAMAAT_OVER))
        am.cancel(buildBoundaryIntent(ctx, LEGACY_REQ_MIDNIGHT))
        am.cancel(buildBoundaryIntent(ctx, LEGACY_REQ_PRAYER_EXPIRE_TICK))
        am.cancel(buildBoundaryIntent(ctx, LEGACY_REQ_JAMAAT_EXPIRE_TICK))
        // Cancel the very-old home_widget BACKGROUND PI used at request code 2.
        val legacyHwIntent = Intent(HOME_WIDGET_BACKGROUND_ACTION)
            .setComponent(ComponentName(ctx, HOME_WIDGET_BACKGROUND_RECEIVER))
            .setData(Uri.parse(BOUNDARY_URI))
        am.cancel(
            PendingIntent.getBroadcast(
                ctx,
                LEGACY_REQ_ALARM,
                legacyHwIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        )
    }

    private fun triggerDartRefresh(ctx: Context) {
        val intent = Intent(HOME_WIDGET_BACKGROUND_ACTION)
            .setComponent(ComponentName(ctx, HOME_WIDGET_BACKGROUND_RECEIVER))
            .setData(Uri.parse(BOUNDARY_URI))
        val pi = PendingIntent.getBroadcast(
            ctx,
            LEGACY_REQ_SELF_HEAL,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        try {
            pi.send()
            logd("triggered Dart refresh")
        } catch (e: PendingIntent.CanceledException) {
            Log.w(TAG, "Dart refresh PI cancelled", e)
        }
    }

    private fun jamaatStateLabel(state: RenderState): String = when {
        state.jamaatCountdownEpoch > 0L -> "countdown"
        state.jamaatTextUsesTimeStyle -> "ongoing|over"
        state.jamaatLabel.isEmpty() -> "na"
        else -> "static"
    }

    private fun RawSchedule.todayCurrentPeriod(now: Long): String {
        var current = "Isha"
        for (name in listOf("Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha")) {
            val e = today[name] ?: 0L
            if (e in 1L..now) current = name
        }
        return current
    }

    private fun logd(message: String) {
        if (Log.isLoggable(TAG, Log.DEBUG)) Log.d(TAG, message)
    }
}
