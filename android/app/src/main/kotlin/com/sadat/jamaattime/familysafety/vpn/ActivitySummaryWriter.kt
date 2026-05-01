package com.sadat.jamaattime.familysafety.vpn

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.atomic.AtomicReference

class ActivitySummaryWriter(private val context: Context) {

    companion object {
        private const val PREFS_NAME = "family_safety_activity_summary"
        private const val KEY_ROWS = "rows"
        const val DEFAULT_RETENTION_DAYS = 30
        private const val MAX_RETAIN_DAYS = DEFAULT_RETENTION_DAYS
        private val DATE_FORMAT: ThreadLocal<SimpleDateFormat> = object : ThreadLocal<SimpleDateFormat>() {
            override fun initialValue(): SimpleDateFormat {
                return SimpleDateFormat("yyyyMMdd", Locale.US).apply {
                    timeZone = TimeZone.getDefault()
                }
            }
        }
    }

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    /**
     * Increment the count for (today, category). Type-safe: caller must pass a [BlockCategory]
     * enum, never a raw string, so domain names cannot leak into the summary.
     */
    fun increment(category: BlockCategory, by: Int = 1) {
        if (by <= 0) return
        val today = DATE_FORMAT.get()!!.format(Date())
        synchronized(this) {
            val rows = readRowsLocked()
            val key = "$today:${category.id}"
            val current = rows[key] ?: ActivityRow(today, category.id, 0)
            rows[key] = current.copy(count = current.count + by)
            writeRowsLocked(rows.values)
        }
    }

    fun readRange(rangeDays: Int): List<Map<String, Any>> {
        val cutoff = DATE_FORMAT.get()!!.format(Date(System.currentTimeMillis() - rangeDays * 24L * 60 * 60 * 1000))
        synchronized(this) {
            val rows = readRowsLocked()
            return rows.values
                .filter { it.dateYyyymmdd >= cutoff }
                .map {
                    mapOf<String, Any>(
                        "date_yyyymmdd" to it.dateYyyymmdd,
                        "category_id" to it.categoryId,
                        "count" to it.count,
                    )
                }
        }
    }

    fun clear() {
        synchronized(this) { prefs.edit().remove(KEY_ROWS).apply() }
    }

    private data class ActivityRow(
        val dateYyyymmdd: String,
        val categoryId: Int,
        val count: Int,
    )

    private fun readRowsLocked(): MutableMap<String, ActivityRow> {
        val raw = prefs.getString(KEY_ROWS, null) ?: return mutableMapOf()
        val out = mutableMapOf<String, ActivityRow>()
        try {
            val arr = JSONArray(raw)
            val cutoff = DATE_FORMAT.get()!!.format(
                Date(System.currentTimeMillis() - MAX_RETAIN_DAYS * 24L * 60 * 60 * 1000),
            )
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val date = obj.optString("date_yyyymmdd", "")
                val categoryId = obj.optInt("category_id", 0)
                val count = obj.optInt("count", 0)
                if (date.isEmpty() || categoryId <= 0 || count <= 0) continue
                if (date < cutoff) continue
                out["$date:$categoryId"] = ActivityRow(date, categoryId, count)
            }
        } catch (_: Exception) {
            // Corrupt store: drop and start fresh.
        }
        return out
    }

    private fun writeRowsLocked(rows: Iterable<ActivityRow>) {
        val arr = JSONArray()
        for (row in rows) {
            val obj = JSONObject()
            obj.put("date_yyyymmdd", row.dateYyyymmdd)
            obj.put("category_id", row.categoryId)
            obj.put("count", row.count)
            arr.put(obj)
        }
        prefs.edit().putString(KEY_ROWS, arr.toString()).apply()
    }
}
