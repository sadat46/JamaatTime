package com.sadat.jamaattime

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

private val PERIOD_ORDER = listOf("Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha")
private val MAIN_PRAYER_ORDER = listOf("Fajr", "Dhuhr", "Asr", "Maghrib", "Isha")
private const val JAMAAT_ONGOING_WINDOW_MS = 10L * 60 * 1000

data class RawSchedule(
    val today: Map<String, Long>,
    val fajrTomorrow: Long,
    val jamaatToday: Map<String, Long>,
    val computeDay: Long,
    val locale: Localization,
    val timeFormatPattern: String,
)

data class Localization(
    val prayerName: Map<String, String>,
    val jamaatInSuffix: String,
    val jamaatOngoing: String,
    val jamaatOver: String,
    val jamaatNa: String,
    val prayerEndsIn: String,
    val nextPrayerInTemplate: String,
    val nextPrayerJamaatTemplate: String,
    val localeCode: String,
)

data class RenderState(
    val prayerName: String,
    val prayerTimeLabel: String,
    val remainingLabel: String,
    val countdownEpoch: Long,
    val jamaatLabel: String,
    val jamaatValueText: String,
    val jamaatCountdownEpoch: Long,
    val jamaatTextUsesTimeStyle: Boolean,
)

object WidgetState {

    fun compute(now: Long, raw: RawSchedule): RenderState {
        val currentPeriod = currentPeriod(now, raw.today)
        val currentMainPrayer = currentMainPrayer(now, raw.today)
        val nextPeriod = nextPeriod(now, raw.today)

        val nextPeriodEpoch = nextPeriod?.let { raw.today[it] ?: 0L } ?: 0L
        val effectiveNextEpoch =
            if (nextPeriodEpoch > now) nextPeriodEpoch else raw.fajrTomorrow

        val prayerName = raw.locale.prayerName[currentPeriod] ?: currentPeriod
        val currentEpoch = raw.today[currentPeriod] ?: 0L
        val prayerTimeLabel = if (currentEpoch > 0L) {
            formatHm(currentEpoch, raw.timeFormatPattern, raw.locale.localeCode)
        } else {
            "-"
        }

        val countdownEpoch = if (effectiveNextEpoch > now) effectiveNextEpoch else 0L

        val isSunrise = currentPeriod == "Sunrise"
        val remainingLabel = if (isSunrise) {
            val sunriseNext = if (nextPeriod != null && MAIN_PRAYER_ORDER.contains(nextPeriod)) {
                nextPeriod
            } else {
                "Dhuhr"
            }
            val nextName = raw.locale.prayerName[sunriseNext] ?: sunriseNext
            raw.locale.nextPrayerInTemplate.replace("{0}", nextName)
        } else {
            raw.locale.prayerEndsIn
        }

        val jamaat = computeJamaat(
            now = now,
            raw = raw,
            currentPeriod = currentPeriod,
            currentMainPrayer = currentMainPrayer,
            nextPeriod = nextPeriod,
        )

        return RenderState(
            prayerName = prayerName,
            prayerTimeLabel = prayerTimeLabel,
            remainingLabel = remainingLabel,
            countdownEpoch = countdownEpoch,
            jamaatLabel = jamaat.label,
            jamaatValueText = jamaat.valueText,
            jamaatCountdownEpoch = jamaat.countdownEpoch,
            jamaatTextUsesTimeStyle = jamaat.textUsesTimeStyle,
        )
    }

    fun nextBoundaryEpoch(now: Long, raw: RawSchedule, nextLocalMidnight: Long): Long {
        val candidates = mutableListOf<Long>()
        var anyTodayFuture = false
        for (name in PERIOD_ORDER) {
            val e = raw.today[name] ?: 0L
            if (e > now) {
                candidates += e
                anyTodayFuture = true
            }
        }
        if (!anyTodayFuture && raw.fajrTomorrow > now) {
            candidates += raw.fajrTomorrow
        }
        for (name in MAIN_PRAYER_ORDER) {
            val j = raw.jamaatToday[name] ?: 0L
            if (j > 0L) {
                if (j > now) candidates += j
                val over = j + JAMAAT_ONGOING_WINDOW_MS
                if (over > now) candidates += over
            }
        }
        if (nextLocalMidnight > now) candidates += nextLocalMidnight

        return if (candidates.isEmpty()) now + 60_000L else candidates.min()
    }

    fun isNewLocalDay(lastComputeDay: Long, todayMidnight: Long): Boolean =
        lastComputeDay > 0L && todayMidnight != lastComputeDay

    fun formatHm(epoch: Long, pattern: String, localeCode: String): String {
        val fmt = SimpleDateFormat(pattern, Locale.US)
        fmt.timeZone = TimeZone.getDefault()
        val s = fmt.format(Date(epoch))
        return if (localeCode == "bn") toBanglaDigits(s) else s
    }

    fun localMidnightEpoch(epoch: Long, tz: TimeZone = TimeZone.getDefault()): Long {
        val cal = Calendar.getInstance(tz)
        cal.timeInMillis = epoch
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    fun nextLocalMidnightEpoch(epoch: Long, tz: TimeZone = TimeZone.getDefault()): Long {
        val cal = Calendar.getInstance(tz)
        cal.timeInMillis = epoch
        cal.add(Calendar.DAY_OF_MONTH, 1)
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private data class JamaatSub(
        val label: String,
        val valueText: String,
        val countdownEpoch: Long,
        val textUsesTimeStyle: Boolean,
    )

    private fun computeJamaat(
        now: Long,
        raw: RawSchedule,
        currentPeriod: String,
        currentMainPrayer: String,
        nextPeriod: String?,
    ): JamaatSub {
        if (currentPeriod == "Sunrise") {
            val sunriseNext = if (nextPeriod != null && MAIN_PRAYER_ORDER.contains(nextPeriod)) {
                nextPeriod
            } else {
                "Dhuhr"
            }
            val jamaatEpoch = raw.jamaatToday[sunriseNext] ?: 0L
            if (jamaatEpoch <= 0L) {
                return JamaatSub(raw.locale.jamaatNa, "", 0L, false)
            }
            val prayerLabel = raw.locale.prayerName[sunriseNext] ?: sunriseNext
            val timeLabel = formatHm(jamaatEpoch, raw.timeFormatPattern, raw.locale.localeCode)
            val label = raw.locale.nextPrayerJamaatTemplate
                .replace("{0}", prayerLabel)
                .replace("{1}", timeLabel)
            return JamaatSub(label, "", 0L, false)
        }

        val fajrToday = raw.today["Fajr"] ?: 0L
        val isOvernightIsha = currentPeriod == "Isha" && fajrToday > 0L && now < fajrToday
        if (isOvernightIsha) {
            return overSub(raw)
        }

        val jamaatEpoch = raw.jamaatToday[currentMainPrayer] ?: 0L
        if (jamaatEpoch <= 0L) {
            return JamaatSub(raw.locale.jamaatNa, "", 0L, false)
        }

        if (now < jamaatEpoch) {
            return JamaatSub(
                label = raw.locale.jamaatInSuffix,
                valueText = "",
                countdownEpoch = jamaatEpoch,
                textUsesTimeStyle = false,
            )
        }
        if (now < jamaatEpoch + JAMAAT_ONGOING_WINDOW_MS) {
            return ongoingSub(raw)
        }
        return overSub(raw)
    }

    private fun overSub(raw: RawSchedule): JamaatSub {
        val base = baseLabel(raw.locale.jamaatInSuffix)
        return JamaatSub(
            label = base,
            valueText = statusValue(raw.locale.jamaatOver, base),
            countdownEpoch = 0L,
            textUsesTimeStyle = true,
        )
    }

    private fun ongoingSub(raw: RawSchedule): JamaatSub {
        val base = baseLabel(raw.locale.jamaatInSuffix)
        return JamaatSub(
            label = base,
            valueText = statusValue(raw.locale.jamaatOngoing, base),
            countdownEpoch = 0L,
            textUsesTimeStyle = true,
        )
    }

    private fun baseLabel(seedRaw: String): String {
        val seed = seedRaw.trim()
        val firstSpace = seed.indexOf(' ')
        return if (firstSpace > 0) seed.substring(0, firstSpace).trim() else seed
    }

    private fun statusValue(fullLabelRaw: String, baseLabelRaw: String): String {
        val full = fullLabelRaw.trim()
        val base = baseLabelRaw.trim()
        if (base.isNotEmpty() && full.startsWith(base)) {
            val remainder = full.substring(base.length).trimStart()
            if (remainder.isNotEmpty()) return remainder
        }
        val firstSpace = full.indexOf(' ')
        if (firstSpace > 0 && firstSpace < full.length - 1) {
            return full.substring(firstSpace + 1).trimStart()
        }
        return full
    }

    private fun currentPeriod(now: Long, today: Map<String, Long>): String {
        var current = "Isha"
        for (name in PERIOD_ORDER) {
            val e = today[name] ?: 0L
            if (e > 0L && e <= now) current = name
        }
        return current
    }

    private fun currentMainPrayer(now: Long, today: Map<String, Long>): String {
        var current = "Isha"
        for (name in MAIN_PRAYER_ORDER) {
            val e = today[name] ?: 0L
            if (e > 0L && e <= now) current = name
        }
        return current
    }

    private fun nextPeriod(now: Long, today: Map<String, Long>): String? {
        for (name in PERIOD_ORDER) {
            val e = today[name] ?: 0L
            if (e > now) return name
        }
        return null
    }

    private fun toBanglaDigits(s: String): String = buildString(s.length) {
        for (c in s) {
            append(if (c in '0'..'9') ('০'.code + (c - '0')).toChar() else c)
        }
    }
}
