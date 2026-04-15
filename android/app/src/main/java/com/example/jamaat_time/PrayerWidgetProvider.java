package com.example.jamaat_time;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.SystemClock;
import android.util.Log;
import android.widget.RemoteViews;

public class PrayerWidgetProvider extends AppWidgetProvider {
    private static final String TAG = "PrayerWidgetProvider";
    private static final int ALARM_REQUEST_CODE = 2;
    private static final int SELF_HEAL_REQUEST_CODE = 3;
    private static final String HOME_WIDGET_BACKGROUND_ACTION =
        "es.antonborri.home_widget.action.BACKGROUND";
    private static final String HOME_WIDGET_BACKGROUND_RECEIVER =
        "es.antonborri.home_widget.HomeWidgetBackgroundReceiver";
    private static final String BOUNDARY_URI = "homewidget://boundary";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        try {
            // Must match home_widget plugin's PREFERENCES constant (HomeWidgetPlugin.kt)
            SharedPreferences prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE);
            String prayerName = prefs.getString("prayer_name", "-");
            String prayerTime = prefs.getString("prayer_time", "-");
            String remainingLabel = prefs.getString("remaining_label", "Remaining Time");
            long nextEpoch = prefs.getLong("next_prayer_epoch_millis", 0L);
            boolean running = prefs.getBoolean("countdown_running", false);
            // 4 dynamic prayer row slots (current prayer excluded by Flutter side)
            String rowLabel1 = prefs.getString("row_label_1", "-");
            String rowTime1 = prefs.getString("row_time_1", "-");
            String rowLabel2 = prefs.getString("row_label_2", "-");
            String rowTime2 = prefs.getString("row_time_2", "-");
            String rowLabel3 = prefs.getString("row_label_3", "-");
            String rowTime3 = prefs.getString("row_time_3", "-");
            String rowLabel4 = prefs.getString("row_label_4", "-");
            String rowTime4 = prefs.getString("row_time_4", "-");
            String islamicDate = prefs.getString("islamic_date", "-");
            String location = prefs.getString("location", "-");

            Log.d(TAG, "Widget update - prayer: " + prayerName + ", next epoch: " + nextEpoch);

            for (int appWidgetId : appWidgetIds) {
                RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.prayer_widget);
                views.setTextViewText(R.id.prayer_name, prayerName);
                views.setTextViewText(R.id.prayer_time, prayerTime);
                views.setTextViewText(R.id.remaining_label, remainingLabel);

                if (running && nextEpoch > System.currentTimeMillis()) {
                    long base = SystemClock.elapsedRealtime() + (nextEpoch - System.currentTimeMillis());
                    views.setChronometerCountDown(R.id.remaining_time, true);
                    views.setChronometer(R.id.remaining_time, base, null, true);
                } else {
                    views.setChronometer(R.id.remaining_time, 0, null, false);
                    views.setTextViewText(R.id.remaining_time, "-");
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
                refreshIntent.setData(Uri.parse("homewidget://refresh"));
                PendingIntent refreshPendingIntent = PendingIntent.getBroadcast(
                    context, 1, refreshIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
                views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent);

                appWidgetManager.updateAppWidget(appWidgetId, views);
            }

            if (running && nextEpoch > System.currentTimeMillis()) {
                scheduleBoundaryAlarm(context, nextEpoch);
            } else if (running && nextEpoch > 0L && nextEpoch <= System.currentTimeMillis()) {
                // Self-heal: prefs say countdown is running but next-epoch is in the past.
                // Trigger Dart background callback to recompute fresh prayer data.
                triggerDartRefresh(context);
            }
        } catch (Exception e) {
            Log.e(TAG, "Error updating widget", e);
        }
    }

    private PendingIntent buildBoundaryPendingIntent(Context context) {
        Intent intent = new Intent(HOME_WIDGET_BACKGROUND_ACTION)
            .setComponent(new ComponentName(context, HOME_WIDGET_BACKGROUND_RECEIVER))
            .setData(Uri.parse(BOUNDARY_URI));
        return PendingIntent.getBroadcast(
            context, ALARM_REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private void scheduleBoundaryAlarm(Context context, long epochMillis) {
        // +1s so Flutter's current/next-prayer logic has crossed the boundary before we read prefs
        long fireAt = epochMillis + 1000L;
        PendingIntent pi = buildBoundaryPendingIntent(context);
        try {
            AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (am == null) return;
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pi);
            Log.d(TAG, "Boundary alarm scheduled for " + fireAt);
        } catch (SecurityException e) {
            // Inexact fallback if exact-alarm permission was revoked at runtime (API 31+)
            Log.w(TAG, "Exact alarm denied, falling back to inexact", e);
            AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
            if (am == null) return;
            am.set(AlarmManager.RTC_WAKEUP, fireAt, pi);
        }
    }

    private void triggerDartRefresh(Context context) {
        Intent intent = new Intent(HOME_WIDGET_BACKGROUND_ACTION)
            .setComponent(new ComponentName(context, HOME_WIDGET_BACKGROUND_RECEIVER))
            .setData(Uri.parse(BOUNDARY_URI));
        PendingIntent pi = PendingIntent.getBroadcast(
            context, SELF_HEAL_REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        try {
            pi.send();
            Log.d(TAG, "Self-heal: triggered Dart refresh for stale prefs");
        } catch (PendingIntent.CanceledException e) {
            Log.w(TAG, "Self-heal pending intent cancelled", e);
        }
    }

    private void cancelBoundaryAlarm(Context context) {
        AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;
        am.cancel(buildBoundaryPendingIntent(context));
    }

    @Override
    public void onEnabled(Context context) {
        super.onEnabled(context);
        Log.d(TAG, "Widget enabled");
    }

    @Override
    public void onDisabled(Context context) {
        super.onDisabled(context);
        cancelBoundaryAlarm(context);
        Log.d(TAG, "Widget disabled");
    }
}
