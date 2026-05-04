package com.sadat.jamaattime

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
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

        val intent = Intent(ctx, PrayerWidgetProvider::class.java)
            .setAction(PrayerWidgetProvider.ACTION_BOUNDARY_TICK)
        ctx.sendBroadcast(intent)
        return Result.success()
    }
}
