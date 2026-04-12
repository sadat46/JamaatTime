package com.example.jamaat_time;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.widget.RemoteViews;

public class PrayerWidgetProvider extends AppWidgetProvider {
    private static final String TAG = "PrayerWidgetProvider";
    private static final int COMPACT_LAYOUT_MAX_MIN_HEIGHT_DP = 190;

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        updateWidgets(context, appWidgetManager, appWidgetIds);
    }

    @Override
    public void onAppWidgetOptionsChanged(
        Context context,
        AppWidgetManager appWidgetManager,
        int appWidgetId,
        Bundle newOptions
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions);
        updateWidgets(context, appWidgetManager, new int[]{appWidgetId});
    }

    private void updateWidgets(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        try {
            // Must match home_widget plugin's PREFERENCES constant (HomeWidgetPlugin.kt)
            SharedPreferences prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE);
            String prayerName = prefs.getString("prayer_name", "-");
            String prayerTime = prefs.getString("prayer_time", "-");
            String remainingLabel = prefs.getString("remaining_label", "Remaining Time");
            String remainingTime = prefs.getString("remaining_time", "-");
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

            Log.d(TAG, "Widget update - prayer: " + prayerName + ", time: " + prayerTime);

            for (int appWidgetId : appWidgetIds) {
                RemoteViews views = new RemoteViews(
                    context.getPackageName(),
                    resolveLayoutId(appWidgetManager, appWidgetId)
                );
                views.setTextViewText(R.id.prayer_name, prayerName);
                views.setTextViewText(R.id.prayer_time, prayerTime);
                views.setTextViewText(R.id.remaining_label, remainingLabel);
                views.setTextViewText(R.id.remaining_time, remainingTime);
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
        } catch (Exception e) {
            Log.e(TAG, "Error updating widget", e);
        }
    }

    private int resolveLayoutId(AppWidgetManager appWidgetManager, int appWidgetId) {
        Bundle options = appWidgetManager.getAppWidgetOptions(appWidgetId);
        int minHeight = 0;
        if (options != null) {
            minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0);
        }
        if (minHeight <= 0 || minHeight < COMPACT_LAYOUT_MAX_MIN_HEIGHT_DP) {
            return R.layout.prayer_widget_compact;
        }
        return R.layout.prayer_widget;
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
