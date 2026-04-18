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
import android.os.SystemClock;
import android.util.Log;
import android.view.View;
import android.widget.RemoteViews;

import java.util.Locale;

public class PrayerWidgetProvider extends AppWidgetProvider {
    private static final String TAG = "PrayerWidgetProvider";
    private static final int ALARM_REQUEST_CODE = 2;
    private static final int SELF_HEAL_REQUEST_CODE = 3;
    private static final int TICK_REQUEST_CODE = 4;
    private static final String HOME_WIDGET_BACKGROUND_ACTION =
        "es.antonborri.home_widget.action.BACKGROUND";
    private static final String HOME_WIDGET_BACKGROUND_RECEIVER =
        "es.antonborri.home_widget.HomeWidgetBackgroundReceiver";
    private static final String BOUNDARY_URI = "homewidget://boundary";
    private static final String TICK_ACTION = "com.sadat.jamaattime.action.WIDGET_TICK";

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
            String jamaatLabel = prefs.getString("jamaat_label", "Jamaat N/A");
            long jamaatEpoch = prefs.getLong("jamaat_epoch_millis", 0L);
            boolean jamaatRunning = prefs.getBoolean("jamaat_countdown_running", false);
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
            String localeCode = prefs.getString("locale_code", "en");
            boolean isBangla = "bn".equalsIgnoreCase(localeCode);

            Log.d(TAG, "Widget update - prayer: " + prayerName + ", next epoch: " + nextEpoch);
            long nowMillis = System.currentTimeMillis();

            for (int appWidgetId : appWidgetIds) {
                RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.prayer_widget);
                views.setTextViewText(R.id.prayer_name, prayerName);
                views.setTextViewText(R.id.prayer_time, prayerTime);
                views.setTextViewText(R.id.remaining_label, remainingLabel);
                views.setTextViewText(R.id.jamaat_label, jamaatLabel);

                if (running && nextEpoch > nowMillis) {
                    if (isBangla) {
                        views.setChronometer(R.id.remaining_time, 0, null, false);
                        views.setTextViewText(
                            R.id.remaining_time,
                            formatBanglaCountdown(nextEpoch, nowMillis)
                        );
                    } else {
                        long base = SystemClock.elapsedRealtime() + (nextEpoch - nowMillis);
                        views.setChronometerCountDown(R.id.remaining_time, true);
                        views.setChronometer(R.id.remaining_time, base, null, true);
                    }
                } else {
                    views.setChronometer(R.id.remaining_time, 0, null, false);
                    views.setTextViewText(R.id.remaining_time, "-");
                }

                if (jamaatRunning && jamaatEpoch > nowMillis) {
                    views.setViewVisibility(R.id.jamaat_time, View.VISIBLE);
                    if (isBangla) {
                        views.setChronometer(R.id.jamaat_time, 0, null, false);
                        views.setTextViewText(
                            R.id.jamaat_time,
                            formatBanglaCountdown(jamaatEpoch, nowMillis)
                        );
                    } else {
                        long jamaatBase = SystemClock.elapsedRealtime() + (jamaatEpoch - nowMillis);
                        views.setChronometerCountDown(R.id.jamaat_time, true);
                        views.setChronometer(R.id.jamaat_time, jamaatBase, null, true);
                    }
                } else {
                    views.setViewVisibility(R.id.jamaat_time, View.GONE);
                    views.setChronometer(R.id.jamaat_time, 0, null, false);
                    views.setTextViewText(R.id.jamaat_time, "-");
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

            long nextBoundaryEpoch = getNextBoundaryEpoch(
                nowMillis, running, nextEpoch, jamaatRunning, jamaatEpoch);
            if (nextBoundaryEpoch > 0L) {
                scheduleBoundaryAlarm(context, nextBoundaryEpoch);
            } else if ((running && nextEpoch > 0L && nextEpoch <= nowMillis)
                    || (jamaatRunning && jamaatEpoch > 0L && jamaatEpoch <= nowMillis)) {
                // Self-heal: prefs say countdown is running but next-epoch is in the past.
                // Trigger Dart background callback to recompute fresh prayer data.
                triggerDartRefresh(context);
            }

            if (isBangla && ((running && nextEpoch > nowMillis) || (jamaatRunning && jamaatEpoch > nowMillis))) {
                scheduleTickAlarm(context, nowMillis);
            } else {
                cancelTickAlarm(context);
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

    private PendingIntent buildTickPendingIntent(Context context) {
        Intent intent = new Intent(context, PrayerWidgetProvider.class).setAction(TICK_ACTION);
        return PendingIntent.getBroadcast(
            context, TICK_REQUEST_CODE, intent,
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

    private void scheduleTickAlarm(Context context, long nowMillis) {
        long nextMinute = ((nowMillis / 60000L) + 1L) * 60000L;
        PendingIntent pi = buildTickPendingIntent(context);
        AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;
        try {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextMinute, pi);
        } catch (SecurityException e) {
            am.set(AlarmManager.RTC_WAKEUP, nextMinute, pi);
        }
    }

    private void cancelTickAlarm(Context context) {
        AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;
        am.cancel(buildTickPendingIntent(context));
    }

    private void cancelBoundaryAlarm(Context context) {
        AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (am == null) return;
        am.cancel(buildBoundaryPendingIntent(context));
    }

    private long getNextBoundaryEpoch(
        long nowMillis,
        boolean prayerRunning,
        long prayerEpoch,
        boolean jamaatRunning,
        long jamaatEpoch
    ) {
        long nextBoundary = 0L;
        if (prayerRunning && prayerEpoch > nowMillis) {
            nextBoundary = prayerEpoch;
        }
        if (jamaatRunning && jamaatEpoch > nowMillis) {
            nextBoundary = (nextBoundary == 0L) ? jamaatEpoch : Math.min(nextBoundary, jamaatEpoch);
        }
        return nextBoundary;
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
        cancelTickAlarm(context);
        Log.d(TAG, "Widget disabled");
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);
        if (intent == null) return;
        if (TICK_ACTION.equals(intent.getAction())) {
            AppWidgetManager manager = AppWidgetManager.getInstance(context);
            int[] ids = manager.getAppWidgetIds(
                new ComponentName(context, PrayerWidgetProvider.class)
            );
            if (ids != null && ids.length > 0) {
                onUpdate(context, manager, ids);
            }
        }
    }

    private String formatBanglaCountdown(long targetEpochMillis, long nowMillis) {
        long diffMillis = targetEpochMillis - nowMillis;
        if (diffMillis <= 0L) return "-";
        long totalMinutes = diffMillis / 60000L;
        long hours = totalMinutes / 60L;
        long minutes = totalMinutes % 60L;
        String latin = String.format(Locale.US, "%02d:%02d", hours, minutes);
        return toBanglaDigits(latin);
    }

    private String toBanglaDigits(String text) {
        StringBuilder builder = new StringBuilder(text.length());
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            if (c >= '0' && c <= '9') {
                builder.append((char) ('\u09E6' + (c - '0')));
            } else {
                builder.append(c);
            }
        }
        return builder.toString();
    }
}
