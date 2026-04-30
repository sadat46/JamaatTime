package com.sadat.jamaattime;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Build;
import android.os.SystemClock;
import android.util.Log;
import android.view.View;
import android.widget.RemoteViews;

import java.util.Calendar;

public class PrayerWidgetProvider extends AppWidgetProvider {
    private static final String TAG = "PrayerWidgetProvider";
    private static final int MAINTENANCE_INTERVAL_HOURS = 6;

    // Legacy request codes — kept only to cancel stale PendingIntents on upgrade.
    private static final int ALARM_REQUEST_CODE      = 2;
    private static final int SELF_HEAL_REQUEST_CODE  = 3;

    // New self-targeted boundary alarms (Layer 1).
    private static final String ACTION_BOUNDARY_TICK = "com.sadat.jamaattime.action.BOUNDARY_TICK";
    private static final String EXTRA_TICK_KIND      = "com.sadat.jamaattime.extra.TICK_KIND";
    private static final int    REQ_PRAYER_BOUNDARY  = 10;
    private static final int    REQ_JAMAAT_BOUNDARY  = 11;
    private static final int    REQ_JAMAAT_OVER      = 12;
    // Distinct slots — must NOT share request codes; Intent.filterEquals ignores extras,
    // so same code + same action = same PendingIntent, causing later set*() to cancel earlier ones.
    private static final int    REQ_MIDNIGHT         = 13;
    private static final int    REQ_PRAYER_EXPIRE_TICK  = 14;
    private static final int    REQ_JAMAAT_EXPIRE_TICK  = 15;

    private static final String HOME_WIDGET_BACKGROUND_ACTION =
        "es.antonborri.home_widget.action.BACKGROUND";
    private static final String HOME_WIDGET_BACKGROUND_RECEIVER =
        "es.antonborri.home_widget.HomeWidgetBackgroundReceiver";
    private static final String BOUNDARY_URI = "homewidget://boundary";
    private static final String REFRESH_URI  = "homewidget://refresh";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        try {
            // Must match home_widget plugin's PREFERENCES constant (HomeWidgetPlugin.kt)
            SharedPreferences prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE);
            String prayerName    = prefs.getString("prayer_name", "-");
            String prayerTime    = prefs.getString("prayer_time", "-");
            String remainingLabel = prefs.getString("remaining_label", "Remaining Time");
            long nextEpoch       = readEpochMillis(prefs, "next_prayer_epoch_millis");
            boolean running      = prefs.getBoolean("countdown_running", false);
            String jamaatLabel   = prefs.getString("jamaat_label", "Jamaat N/A");
            String jamaatValueText = prefs.getString("jamaat_value_text", "");
            long jamaatEpoch     = readEpochMillis(prefs, "jamaat_epoch_millis");
            boolean jamaatRunning = prefs.getBoolean("jamaat_countdown_running", false);
            boolean jamaatTimeStyle = prefs.getBoolean("jamaat_time_style", false);
            long jamaatOverEpoch = readEpochMillis(prefs, "jamaat_over_epoch_millis");
            // 4 dynamic prayer row slots (current prayer excluded by Flutter side)
            String rowLabel1 = prefs.getString("row_label_1", "-");
            String rowTime1  = prefs.getString("row_time_1", "-");
            String rowLabel2 = prefs.getString("row_label_2", "-");
            String rowTime2  = prefs.getString("row_time_2", "-");
            String rowLabel3 = prefs.getString("row_label_3", "-");
            String rowTime3  = prefs.getString("row_time_3", "-");
            String rowLabel4 = prefs.getString("row_label_4", "-");
            String rowTime4  = prefs.getString("row_time_4", "-");
            String islamicDate = prefs.getString("islamic_date", "-");
            String location    = prefs.getString("location", "-");

            logDebug("Widget update - prayer: " + prayerName + ", next epoch: " + nextEpoch);
            long nowMillis = System.currentTimeMillis();

            // Epoch-based staleness — not flag-based — so the Ongoing→Over transition is caught.
            boolean prayerStale   = nextEpoch    > 0L && nextEpoch    + 1000L <= nowMillis;
            boolean jamaatStale   = jamaatEpoch  > 0L && jamaatEpoch  + 1000L <= nowMillis;
            boolean needsSelfHeal = prayerStale || jamaatStale;

            for (int appWidgetId : appWidgetIds) {
                RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.prayer_widget);
                views.setTextViewText(R.id.prayer_name, prayerName);
                views.setTextViewText(R.id.prayer_time, prayerTime);
                views.setTextViewText(R.id.remaining_label, remainingLabel);
                views.setTextViewText(R.id.jamaat_label, jamaatLabel);

                if (running && nextEpoch > nowMillis) {
                    long base = SystemClock.elapsedRealtime() + (nextEpoch - nowMillis);
                    views.setChronometerCountDown(R.id.remaining_time, true);
                    views.setChronometer(R.id.remaining_time, base, null, true);
                } else {
                    views.setChronometer(R.id.remaining_time, 0, null, false);
                    views.setTextViewText(R.id.remaining_time, "-");
                    // Layer 2: if a known boundary is in the past, re-tick soon so we don't
                    // stay on "-" while waiting for Dart to finish recomputing.
                    if (nextEpoch > 0L) {
                        scheduleBoundaryAlarm(context,
                            nowMillis + 1500L,
                            buildSelfTickIntent(context, REQ_PRAYER_EXPIRE_TICK, "prayer-expire"),
                            "prayer-expire");
                    }
                }

                if (jamaatRunning && jamaatEpoch > nowMillis) {
                    views.setViewVisibility(R.id.jamaat_label, View.VISIBLE);
                    views.setViewVisibility(R.id.jamaat_time, View.VISIBLE);
                    long jamaatBase = SystemClock.elapsedRealtime() + (jamaatEpoch - nowMillis);
                    views.setChronometerCountDown(R.id.jamaat_time, true);
                    views.setChronometer(R.id.jamaat_time, jamaatBase, null, true);
                } else if (jamaatTimeStyle) {
                    views.setViewVisibility(R.id.jamaat_label, View.VISIBLE);
                    views.setViewVisibility(R.id.jamaat_time, View.VISIBLE);
                    views.setChronometer(R.id.jamaat_time, 0, null, false);
                    String tealValue = (jamaatValueText != null && !jamaatValueText.isEmpty())
                        ? jamaatValueText
                        : jamaatLabel;
                    views.setTextViewText(R.id.jamaat_time, tealValue);
                } else {
                    views.setViewVisibility(R.id.jamaat_label, View.VISIBLE);
                    views.setViewVisibility(R.id.jamaat_time, View.GONE);
                    views.setChronometer(R.id.jamaat_time, 0, null, false);
                    views.setTextViewText(R.id.jamaat_time, "-");
                    // Layer 2: similarly re-tick if jamaat epoch is known but stale.
                    if (jamaatEpoch > 0L) {
                        scheduleBoundaryAlarm(context,
                            nowMillis + 1500L,
                            buildSelfTickIntent(context, REQ_JAMAAT_EXPIRE_TICK, "jamaat-expire"),
                            "jamaat-expire");
                    }
                }

                views.setTextViewText(R.id.row_label_1, rowLabel1);
                views.setTextViewText(R.id.row_time_1, rowTime1);
                views.setTextViewText(R.id.row_label_2, rowLabel2);
                views.setTextViewText(R.id.row_time_2, rowTime2);
                views.setTextViewText(R.id.row_label_3, rowLabel3);
                views.setTextViewText(R.id.row_time_3, rowTime3);
                views.setTextViewText(R.id.row_label_4, rowLabel4);
                views.setTextViewText(R.id.row_time_4, rowTime4);
                views.setTextViewText(R.id.islamic_date, islamicDate);
                views.setTextViewText(R.id.location, location);

                // Click anywhere on widget opens the app
                Intent launchIntent = context.getPackageManager()
                    .getLaunchIntentForPackage(context.getPackageName());
                if (launchIntent != null) {
                    PendingIntent pendingIntent = PendingIntent.getActivity(
                        context, 0, launchIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
                    views.setOnClickPendingIntent(R.id.widget_root, pendingIntent);
                }

                // Refresh button triggers HomeWidget background callback
                Intent refreshIntent = new Intent("es.antonborri.home_widget.action.BACKGROUND");
                refreshIntent.setComponent(new ComponentName(
                    context, "es.antonborri.home_widget.HomeWidgetBackgroundReceiver"));
                refreshIntent.setData(Uri.parse(REFRESH_URI));
                PendingIntent refreshPendingIntent = PendingIntent.getBroadcast(
                    context, 1, refreshIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
                views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent);

                appWidgetManager.updateAppWidget(appWidgetId, views);
            }

            if (needsSelfHeal) {
                // Self-heal: ask Dart to rewrite stale prefs; re-render follows via onUpdate.
                triggerDartRefresh(context);
            }

            // Schedule independent alarms for each upcoming boundary.
            scheduleAllAlarms(context, nowMillis, nextEpoch, jamaatEpoch, jamaatOverEpoch);

        } catch (Exception e) {
            Log.e(TAG, "Error updating widget", e);
        }
    }

    // -------------------------------------------------------------------------
    // Alarm helpers (Layer 1)
    // -------------------------------------------------------------------------

    private PendingIntent buildSelfTickIntent(Context ctx, int requestCode, String kind) {
        Intent i = new Intent(ctx, PrayerWidgetProvider.class)
            .setAction(ACTION_BOUNDARY_TICK)
            .putExtra(EXTRA_TICK_KIND, kind);
        return PendingIntent.getBroadcast(
            ctx, requestCode, i,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private void scheduleBoundaryAlarm(Context ctx, long fireAt, PendingIntent pi, String kind) {
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;
        try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pi);
                logDebug("alarm scheduled kind=" + kind + " via exactIdle");
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pi);
                logDebug("alarm scheduled kind=" + kind + " via inexactIdle");
            }
        } catch (SecurityException e) {
            Log.w(TAG, "Exact alarm denied, falling back to inexact idle alarm", e);
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pi);
        }
    }

    private void scheduleAllAlarms(Context ctx, long nowMillis,
            long prayerEpoch, long jamaatEpoch, long jamaatOverEpoch) {
        if (prayerEpoch > nowMillis) {
            scheduleBoundaryAlarm(ctx, prayerEpoch + 1000L,
                buildSelfTickIntent(ctx, REQ_PRAYER_BOUNDARY, "prayer"), "prayer");
        }
        if (jamaatEpoch > nowMillis) {
            scheduleBoundaryAlarm(ctx, jamaatEpoch + 1000L,
                buildSelfTickIntent(ctx, REQ_JAMAAT_BOUNDARY, "jamaat"), "jamaat");
        }
        if (jamaatOverEpoch > nowMillis) {
            scheduleBoundaryAlarm(ctx, jamaatOverEpoch + 1000L,
                buildSelfTickIntent(ctx, REQ_JAMAAT_OVER, "over"), "over");
        }
        // Midnight fallback — distinct slot so it cannot cancel the prayer-boundary alarm.
        long midnight = getNextMidnightEpoch(nowMillis);
        AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
        if (am != null && midnight > nowMillis) {
            PendingIntent midPi = buildSelfTickIntent(ctx, REQ_MIDNIGHT, "midnight");
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, midnight, midPi);
        }
    }

    private void cancelAllAlarms(Context context) {
        AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;
        am.cancel(buildSelfTickIntent(context, REQ_PRAYER_BOUNDARY,    "prayer"));
        am.cancel(buildSelfTickIntent(context, REQ_JAMAAT_BOUNDARY,    "jamaat"));
        am.cancel(buildSelfTickIntent(context, REQ_JAMAAT_OVER,        "over"));
        am.cancel(buildSelfTickIntent(context, REQ_MIDNIGHT,           "midnight"));
        am.cancel(buildSelfTickIntent(context, REQ_PRAYER_EXPIRE_TICK, "prayer-expire"));
        am.cancel(buildSelfTickIntent(context, REQ_JAMAAT_EXPIRE_TICK, "jamaat-expire"));
        // Legacy alarm that targeted HomeWidgetBackgroundReceiver in older builds.
        am.cancel(buildLegacyBoundaryPendingIntent(context));
    }

    // Kept only to cancel the old ALARM_REQUEST_CODE=2 PendingIntent during upgrade.
    private PendingIntent buildLegacyBoundaryPendingIntent(Context context) {
        Intent intent = new Intent(HOME_WIDGET_BACKGROUND_ACTION)
            .setComponent(new ComponentName(context, HOME_WIDGET_BACKGROUND_RECEIVER))
            .setData(Uri.parse(BOUNDARY_URI));
        return PendingIntent.getBroadcast(
            context, ALARM_REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    // -------------------------------------------------------------------------
    // Dart refresh helper (unchanged semantics)
    // -------------------------------------------------------------------------

    private void triggerDartRefresh(Context context) {
        Intent intent = new Intent(HOME_WIDGET_BACKGROUND_ACTION)
            .setComponent(new ComponentName(context, HOME_WIDGET_BACKGROUND_RECEIVER))
            .setData(Uri.parse(BOUNDARY_URI));
        PendingIntent pi = PendingIntent.getBroadcast(
            context, SELF_HEAL_REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        try {
            pi.send();
            logDebug("Triggered Dart refresh");
        } catch (PendingIntent.CanceledException e) {
            Log.w(TAG, "Dart refresh pending intent cancelled", e);
        }
    }

    // -------------------------------------------------------------------------
    // Utility
    // -------------------------------------------------------------------------

    private long readEpochMillis(SharedPreferences prefs, String key) {
        Object raw = prefs.getAll().get(key);
        if (raw == null) {
            return 0L;
        }
        if (raw instanceof Long) {
            return (Long) raw;
        }
        if (raw instanceof Integer) {
            return ((Integer) raw).longValue();
        }
        if (raw instanceof String) {
            try {
                return Long.parseLong((String) raw);
            } catch (NumberFormatException e) {
                Log.w(TAG, "Invalid epoch string for key " + key + ": " + raw);
                return 0L;
            }
        }
        Log.w(TAG, "Unsupported epoch type for key " + key + ": " + raw.getClass().getSimpleName());
        return 0L;
    }

    private long getNextMidnightEpoch(long nowMillis) {
        Calendar midnight = Calendar.getInstance();
        midnight.setTimeInMillis(nowMillis);
        midnight.add(Calendar.DAY_OF_MONTH, 1);
        midnight.set(Calendar.HOUR_OF_DAY, 0);
        midnight.set(Calendar.MINUTE, 0);
        midnight.set(Calendar.SECOND, 0);
        midnight.set(Calendar.MILLISECOND, 0);
        return midnight.getTimeInMillis();
    }

    // -------------------------------------------------------------------------
    // AppWidgetProvider lifecycle
    // -------------------------------------------------------------------------

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);
        if (intent == null) return;
        String action = intent.getAction();
        if (Intent.ACTION_BOOT_COMPLETED.equals(action)
                || Intent.ACTION_MY_PACKAGE_REPLACED.equals(action)) {
            logDebug("System broadcast received: " + action + ", requesting widget refresh");
            // Cancel stale legacy alarm from previous app version.
            cancelAllAlarms(context);
            triggerDartRefresh(context);
            AppWidgetManager appWidgetManager = AppWidgetManager.getInstance(context);
            int[] widgetIds = appWidgetManager.getAppWidgetIds(
                new ComponentName(context, PrayerWidgetProvider.class));
            if (widgetIds != null && widgetIds.length > 0) {
                onUpdate(context, appWidgetManager, widgetIds);
            }
        } else if (ACTION_BOUNDARY_TICK.equals(action)) {
            String kind = intent.getStringExtra(EXTRA_TICK_KIND);
            logDebug("BOUNDARY_TICK received kind=" + kind);
            // Pass 1: re-render immediately from current prefs (also re-arms next alarms).
            AppWidgetManager mgr = AppWidgetManager.getInstance(context);
            int[] ids = mgr.getAppWidgetIds(new ComponentName(context, PrayerWidgetProvider.class));
            if (ids != null && ids.length > 0) {
                onUpdate(context, mgr, ids);
            }
            // Pass 2: ask Dart to recompute and overwrite prefs asynchronously.
            triggerDartRefresh(context);
        }
    }

    @Override
    public void onEnabled(Context context) {
        super.onEnabled(context);
        logDebug("Widget enabled");
        try {
            androidx.work.PeriodicWorkRequest req =
                new androidx.work.PeriodicWorkRequest.Builder(
                    WidgetMaintenanceWorker.class,
                    MAINTENANCE_INTERVAL_HOURS,
                    java.util.concurrent.TimeUnit.HOURS
                ).build();
            androidx.work.WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "widget_maintenance",
                androidx.work.ExistingPeriodicWorkPolicy.KEEP,
                req);
        } catch (Throwable t) {
            Log.w(TAG, "Failed to enqueue maintenance worker from onEnabled", t);
        }
    }

    @Override
    public void onDisabled(Context context) {
        super.onDisabled(context);
        cancelAllAlarms(context);
        androidx.work.WorkManager.getInstance(context).cancelUniqueWork("widget_maintenance");
        logDebug("Widget disabled");
    }

    private static void logDebug(String message) {
        if (Log.isLoggable(TAG, Log.DEBUG)) {
            Log.d(TAG, message);
        }
    }
}
