package com.example.jamaat_time;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.util.Log;
import android.widget.RemoteViews;

public class PrayerWidgetProvider extends AppWidgetProvider {
    private static final String TAG = "PrayerWidgetProvider";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        try {
            // Must match home_widget plugin's PREFERENCES constant (HomeWidgetPlugin.kt)
            SharedPreferences prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE);
            String prayerName = prefs.getString("prayer_name", "-");
            String prayerTime = prefs.getString("prayer_time", "-");
            String remainingLabel = prefs.getString("remaining_label", "Remaining Time");
            String remainingTime = prefs.getString("remaining_time", "-");
            String fajrTime = prefs.getString("fajr_time", "-");
            String dhuhrTime = prefs.getString("dhuhr_time", "-");
            String asrTime = prefs.getString("asr_time", "-");
            String maghribTime = prefs.getString("maghrib_time", "-");
            String ishaTime = prefs.getString("isha_time", "-");
            String islamicDate = prefs.getString("islamic_date", "-");
            String location = prefs.getString("location", "-");

            Log.d(TAG, "Widget update - prayer: " + prayerName + ", time: " + prayerTime);

            for (int appWidgetId : appWidgetIds) {
                RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.prayer_widget);
                views.setTextViewText(R.id.prayer_name, prayerName);
                views.setTextViewText(R.id.prayer_time, prayerTime);
                views.setTextViewText(R.id.remaining_label, remainingLabel);
                views.setTextViewText(R.id.remaining_time, remainingTime);
                views.setTextViewText(R.id.fajr_time, fajrTime);
                views.setTextViewText(R.id.dhuhr_time, dhuhrTime);
                views.setTextViewText(R.id.asr_time, asrTime);
                views.setTextViewText(R.id.maghrib_time, maghribTime);
                views.setTextViewText(R.id.isha_time, ishaTime);
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
        } catch (Exception e) {
            Log.e(TAG, "Error updating widget", e);
        }
    }

    @Override
    public void onEnabled(Context context) {
        super.onEnabled(context);
        Log.d(TAG, "Widget enabled");
    }

    @Override
    public void onDisabled(Context context) {
        super.onDisabled(context);
        Log.d(TAG, "Widget disabled");
    }
}
