package com.sadat.jamaattime

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

class WidgetMaintenanceWorker(ctx: Context, params: WorkerParameters)
    : CoroutineWorker(ctx, params) {

    override suspend fun doWork(): Result {
        val ctx = applicationContext
        val appWidgetManager = AppWidgetManager.getInstance(ctx)
        val widgetIds = appWidgetManager.getAppWidgetIds(
            ComponentName(ctx, PrayerWidgetProvider::class.java)
        )
        if (widgetIds.isEmpty()) {
            return Result.success()
        }

        val intent = Intent("es.antonborri.home_widget.action.BACKGROUND")
            .setComponent(ComponentName(
                ctx, "es.antonborri.home_widget.HomeWidgetBackgroundReceiver"))
            .setData(Uri.parse("homewidget://maintenance"))
        ctx.sendBroadcast(intent)
        return Result.success()
    }
}
