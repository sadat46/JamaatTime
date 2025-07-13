package com.example.jamaat_time;

import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;
import android.widget.RemoteViews;

public class PrayerWidgetProvider extends AppWidgetProvider {
    private static final String TAG = "PrayerWidgetProvider";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        try {
            // Use the correct SharedPreferences key that home_widget package uses
            SharedPreferences prefs = context.getSharedPreferences("HomeWidgetProvider", Context.MODE_PRIVATE);
            String prayerName = prefs.getString("prayer_name", "-");
            String prayerTime = prefs.getString("prayer_time", "-");
            String remainingLabel = prefs.getString("remaining_label", "Remaining Time");
            String remainingTime = prefs.getString("remaining_time", "-");
            String fajrTime = prefs.getString("fajr_time", "-");
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
                views.setTextViewText(R.id.asr_time, asrTime);
                views.setTextViewText(R.id.maghrib_time, maghribTime);
                views.setTextViewText(R.id.isha_time, ishaTime);
                views.setTextViewText(R.id.islamic_date, islamicDate);
                views.setTextViewText(R.id.location, location);
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