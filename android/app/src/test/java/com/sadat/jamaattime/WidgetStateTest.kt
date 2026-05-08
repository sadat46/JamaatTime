package com.sadat.jamaattime

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class WidgetStateTest {

    private val tz: TimeZone = TimeZone.getDefault()

    private fun epoch(year: Int, month: Int, day: Int, hour: Int, minute: Int): Long {
        val cal = Calendar.getInstance(tz)
        cal.clear()
        cal.set(year, month - 1, day, hour, minute, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private fun enLocalization() = Localization(
        prayerName = mapOf(
            "Fajr" to "Fajr",
            "Sunrise" to "Sunrise",
            "Dhuhr" to "Dhuhr",
            "Asr" to "Asr",
            "Maghrib" to "Maghrib",
            "Isha" to "Isha",
        ),
        jamaatInSuffix = "Jamaat in",
        jamaatOngoing = "Jamaat ongoing",
        jamaatOver = "Jamaat ended",
        jamaatNa = "Jamaat N/A",
        prayerEndsIn = "Prayer ends in",
        nextPrayerInTemplate = "{0} in",
        nextPrayerJamaatTemplate = "{0} Jamaat at {1}",
        localeCode = "en",
    )

    private fun bnLocalization() = Localization(
        prayerName = mapOf(
            "Fajr" to "ফজর",
            "Sunrise" to "সূর্যোদয়",
            "Dhuhr" to "যোহর",
            "Asr" to "আসর",
            "Maghrib" to "মাগরিব",
            "Isha" to "এশা",
        ),
        jamaatInSuffix = "জামাত শুরু হতে বাকি",
        jamaatOngoing = "জামাত চলমান",
        jamaatOver = "জামাত শেষ",
        jamaatNa = "জামাত নেই",
        prayerEndsIn = "ওয়াক্ত শেষ হতে বাকি",
        nextPrayerInTemplate = "{0} শুরু হবে",
        nextPrayerJamaatTemplate = "{0} জামাত {1}",
        localeCode = "bn",
    )

    private fun rawEn(
        jamaatTimes: Map<String, Long> = emptyMap(),
        fajrTomorrow: Long = 0L,
        today: Map<String, Long>? = null,
        tomorrow: Map<String, Long> = emptyMap(),
        jamaatTomorrow: Map<String, Long> = emptyMap(),
        computeDay: Long? = null,
        nextComputeDay: Long = 0L,
        fajrDayAfterTomorrow: Long = 0L,
    ): RawSchedule {
        val todaySchedule = today ?: prayerDay(2026, 4, 13)
        return RawSchedule(
            today = todaySchedule,
            fajrTomorrow = fajrTomorrow,
            jamaatToday = jamaatTimes,
            computeDay =
                computeDay ?: WidgetState.localMidnightEpoch(epoch(2026, 4, 13, 0, 1)),
            locale = enLocalization(),
            timeFormatPattern = "HH:mm",
            tomorrow = tomorrow,
            jamaatTomorrow = jamaatTomorrow,
            nextComputeDay = nextComputeDay,
            fajrDayAfterTomorrow = fajrDayAfterTomorrow,
        )
    }

    private fun prayerDay(year: Int, month: Int, day: Int) = mapOf(
        "Fajr" to epoch(year, month, day, 5, 0),
        "Sunrise" to epoch(year, month, day, 6, 15),
        "Dhuhr" to epoch(year, month, day, 12, 10),
        "Asr" to epoch(year, month, day, 15, 40),
        "Maghrib" to epoch(year, month, day, 18, 20),
        "Isha" to epoch(year, month, day, 19, 45),
    )

    private fun jamaatDay(year: Int, month: Int, day: Int) = mapOf(
        "Fajr" to epoch(year, month, day, 5, 20),
        "Dhuhr" to epoch(year, month, day, 12, 25),
        "Asr" to epoch(year, month, day, 15, 55),
        "Maghrib" to epoch(year, month, day, 18, 33),
        "Isha" to epoch(year, month, day, 20, 0),
    )

    private fun jamaatEn() = jamaatDay(2026, 4, 13)

    @Test
    fun fajrPeriod_countdownsToSunrise_andEndsInLabel() {
        val raw = rawEn()
        val now = epoch(2026, 4, 13, 5, 30)
        val s = WidgetState.compute(now, raw)

        assertEquals("Fajr", s.prayerName)
        assertEquals("05:00", s.prayerTimeLabel)
        assertEquals("Prayer ends in", s.remainingLabel)
        assertEquals(epoch(2026, 4, 13, 6, 15), s.countdownEpoch)
    }

    @Test
    fun sunrisePeriod_usesNextPrayerInTemplate_andStaticJamaatLine() {
        val raw = rawEn(jamaatTimes = jamaatEn())
        val now = epoch(2026, 4, 13, 6, 30)
        val s = WidgetState.compute(now, raw)

        assertEquals("Sunrise", s.prayerName)
        assertEquals("Dhuhr in", s.remainingLabel)
        assertEquals("Dhuhr Jamaat at 12:25", s.jamaatLabel)
        assertEquals("", s.jamaatValueText)
        assertEquals(0L, s.jamaatCountdownEpoch)
        assertFalse(s.jamaatTextUsesTimeStyle)
    }

    @Test
    fun beforeJamaat_setsCountdownAndInLabel() {
        val raw = rawEn(jamaatTimes = jamaatEn())
        val now = epoch(2026, 4, 13, 5, 10)
        val s = WidgetState.compute(now, raw)

        assertEquals("Jamaat in", s.jamaatLabel)
        assertEquals("", s.jamaatValueText)
        assertEquals(epoch(2026, 4, 13, 5, 20), s.jamaatCountdownEpoch)
        assertFalse(s.jamaatTextUsesTimeStyle)
    }

    @Test
    fun duringOngoingWindow_setsOngoingValue() {
        val raw = rawEn(jamaatTimes = jamaatEn())
        val now = epoch(2026, 4, 13, 5, 25)
        val s = WidgetState.compute(now, raw)

        assertEquals("Jamaat", s.jamaatLabel)
        assertEquals("ongoing", s.jamaatValueText)
        assertEquals(0L, s.jamaatCountdownEpoch)
        assertTrue(s.jamaatTextUsesTimeStyle)
    }

    @Test
    fun afterOngoingWindow_setsEndedValue() {
        val raw = rawEn(jamaatTimes = jamaatEn())
        val now = epoch(2026, 4, 13, 5, 31)
        val s = WidgetState.compute(now, raw)

        assertEquals("Jamaat", s.jamaatLabel)
        assertEquals("ended", s.jamaatValueText)
        assertEquals(0L, s.jamaatCountdownEpoch)
        assertTrue(s.jamaatTextUsesTimeStyle)
    }

    @Test
    fun missingJamaat_showsNa() {
        val raw = rawEn()
        val now = epoch(2026, 4, 13, 5, 10)
        val s = WidgetState.compute(now, raw)

        assertEquals("Jamaat N/A", s.jamaatLabel)
        assertEquals("", s.jamaatValueText)
        assertEquals(0L, s.jamaatCountdownEpoch)
        assertFalse(s.jamaatTextUsesTimeStyle)
    }

    @Test
    fun afterIsha_overnight_targetsTomorrowFajrAndJamaatOver() {
        val tomorrowFajr = epoch(2026, 4, 14, 5, 1)
        val raw = rawEn(jamaatTimes = jamaatEn(), fajrTomorrow = tomorrowFajr)
        val now = epoch(2026, 4, 13, 23, 0)
        val s = WidgetState.compute(now, raw)

        assertEquals("Isha", s.prayerName)
        assertEquals("Prayer ends in", s.remainingLabel)
        assertEquals(tomorrowFajr, s.countdownEpoch)
    }

    @Test
    fun afterMidnight_beforeFajr_keepsIshaOvernightOverState() {
        val today = prayerDay(2026, 4, 14)
        val jamaat = jamaatDay(2026, 4, 14)
        val raw = RawSchedule(
            today = today,
            fajrTomorrow = 0L,
            jamaatToday = jamaat,
            computeDay = WidgetState.localMidnightEpoch(epoch(2026, 4, 14, 0, 1)),
            locale = enLocalization(),
            timeFormatPattern = "HH:mm",
        )
        val now = epoch(2026, 4, 14, 0, 30)
        val s = WidgetState.compute(now, raw)

        assertEquals("Isha", s.prayerName)
        assertEquals("Prayer ends in", s.remainingLabel)
        assertEquals(epoch(2026, 4, 14, 5, 0), s.countdownEpoch)
        assertEquals("Jamaat", s.jamaatLabel)
        assertEquals("ended", s.jamaatValueText)
        assertTrue(s.jamaatTextUsesTimeStyle)
    }

    @Test
    fun promoteNextDayIfAvailable_returnsNullWhenPayloadMissing() {
        val todayMidnight = WidgetState.localMidnightEpoch(epoch(2026, 4, 14, 0, 1))
        val raw = rawEn(nextComputeDay = todayMidnight)

        assertNull(WidgetState.promoteNextDayIfAvailable(raw, todayMidnight))
    }

    @Test
    fun promotedNextDay_beforeFajrKeepsIshaAndCountsToFajr() {
        val todayMidnight = WidgetState.localMidnightEpoch(epoch(2026, 4, 14, 0, 1))
        val raw = rawEn(
            tomorrow = prayerDay(2026, 4, 14),
            jamaatTomorrow = jamaatDay(2026, 4, 14),
            nextComputeDay = todayMidnight,
            fajrDayAfterTomorrow = epoch(2026, 4, 15, 5, 2),
        )
        val promoted = WidgetState.promoteNextDayIfAvailable(raw, todayMidnight)!!
        val now = epoch(2026, 4, 14, 0, 30)
        val s = WidgetState.compute(now, promoted)

        assertEquals(todayMidnight, promoted.computeDay)
        assertEquals("Isha", s.prayerName)
        assertEquals("Prayer ends in", s.remainingLabel)
        assertEquals(epoch(2026, 4, 14, 5, 0), s.countdownEpoch)
        assertEquals("Jamaat", s.jamaatLabel)
        assertEquals("ended", s.jamaatValueText)
    }

    @Test
    fun promotedNextDay_afterFajrShowsFajrAndJamaatCountdown() {
        val todayMidnight = WidgetState.localMidnightEpoch(epoch(2026, 4, 14, 0, 1))
        val raw = rawEn(
            tomorrow = prayerDay(2026, 4, 14),
            jamaatTomorrow = jamaatDay(2026, 4, 14),
            nextComputeDay = todayMidnight,
            fajrDayAfterTomorrow = epoch(2026, 4, 15, 5, 2),
        )
        val promoted = WidgetState.promoteNextDayIfAvailable(raw, todayMidnight)!!
        val now = epoch(2026, 4, 14, 5, 10)
        val s = WidgetState.compute(now, promoted)

        assertEquals("Fajr", s.prayerName)
        assertEquals("05:00", s.prayerTimeLabel)
        assertEquals(epoch(2026, 4, 14, 6, 15), s.countdownEpoch)
        assertEquals("Jamaat in", s.jamaatLabel)
        assertEquals(epoch(2026, 4, 14, 5, 20), s.jamaatCountdownEpoch)
        assertEquals(
            epoch(2026, 4, 14, 5, 20),
            WidgetState.nextBoundaryEpoch(
                now,
                promoted,
                WidgetState.nextLocalMidnightEpoch(now),
            ),
        )
    }

    @Test
    fun promotedNextDay_recomputesRowsFromPromotedData() {
        val todayMidnight = WidgetState.localMidnightEpoch(epoch(2026, 4, 14, 0, 1))
        val raw = rawEn(
            tomorrow = prayerDay(2026, 4, 14),
            jamaatTomorrow = jamaatDay(2026, 4, 14),
            nextComputeDay = todayMidnight,
            fajrDayAfterTomorrow = epoch(2026, 4, 15, 5, 2),
        )
        val promoted = WidgetState.promoteNextDayIfAvailable(raw, todayMidnight)!!
        val now = epoch(2026, 4, 14, 5, 10)

        assertEquals(
            listOf("Dhuhr", "Asr", "Maghrib", "Isha"),
            WidgetState.rowLabels(now, promoted),
        )
        assertEquals(
            listOf("12:10", "15:40", "18:20", "19:45"),
            WidgetState.rowTimes(now, promoted),
        )
    }

    @Test
    fun banglaLocale_convertsDigitsAndUsesBnTemplates() {
        val raw = rawEn(jamaatTimes = jamaatEn()).copy(locale = bnLocalization())
        val now = epoch(2026, 4, 13, 6, 30)
        val s = WidgetState.compute(now, raw)

        assertEquals("সূর্যোদয়", s.prayerName)
        assertEquals("০৬:১৫", s.prayerTimeLabel)
        assertEquals("যোহর শুরু হবে", s.remainingLabel)
        assertEquals("যোহর জামাত ১২:২৫", s.jamaatLabel)
    }

    @Test
    fun banglaLocale_jamaatInSuffix_usedDirectlyWhenCountingDown() {
        val raw = rawEn(jamaatTimes = jamaatEn()).copy(locale = bnLocalization())
        val now = epoch(2026, 4, 13, 5, 10)
        val s = WidgetState.compute(now, raw)

        assertEquals("জামাত শুরু হতে বাকি", s.jamaatLabel)
        assertTrue(s.jamaatCountdownEpoch > 0L)
    }

    @Test
    fun nextBoundary_picksSmallestFutureCandidate() {
        val raw = rawEn(jamaatTimes = jamaatEn())
        val now = epoch(2026, 4, 13, 5, 10)
        val midnight = WidgetState.nextLocalMidnightEpoch(now)
        val boundary = WidgetState.nextBoundaryEpoch(now, raw, midnight)

        // Earliest future candidate at 05:10 is jamaat-Fajr (05:20)
        assertEquals(epoch(2026, 4, 13, 5, 20), boundary)
    }

    @Test
    fun nextBoundary_includesJamaatOverWindow() {
        val raw = rawEn(jamaatTimes = jamaatEn())
        val now = epoch(2026, 4, 13, 5, 25) // ongoing window for Fajr jamaat
        val midnight = WidgetState.nextLocalMidnightEpoch(now)
        val boundary = WidgetState.nextBoundaryEpoch(now, raw, midnight)

        // Next is Fajr jamaat over (05:30) which precedes Sunrise (06:15)
        assertEquals(epoch(2026, 4, 13, 5, 30), boundary)
    }

    @Test
    fun nextBoundary_fallsBackToTomorrowFajrAfterIsha() {
        val tomorrowFajr = epoch(2026, 4, 14, 5, 1)
        val raw = rawEn(jamaatTimes = emptyMap(), fajrTomorrow = tomorrowFajr)
        val now = epoch(2026, 4, 13, 23, 0)
        val midnight = WidgetState.nextLocalMidnightEpoch(now)
        val boundary = WidgetState.nextBoundaryEpoch(now, raw, midnight)

        // Midnight (00:00 next day) precedes tomorrow Fajr (05:01)
        assertEquals(midnight, boundary)
        assertNotEquals(tomorrowFajr, boundary)
    }

    @Test
    fun isNewLocalDay_detectsRollover() {
        val day1 = WidgetState.localMidnightEpoch(epoch(2026, 4, 13, 12, 0))
        val day2 = WidgetState.localMidnightEpoch(epoch(2026, 4, 14, 1, 0))
        assertTrue(WidgetState.isNewLocalDay(day1, day2))
        assertFalse(WidgetState.isNewLocalDay(day1, day1))
        assertFalse(WidgetState.isNewLocalDay(0L, day2))
    }

    @Test
    fun formatHm_appliesBanglaDigits() {
        val e = epoch(2026, 4, 13, 6, 15)
        assertEquals("06:15", WidgetState.formatHm(e, "HH:mm", "en"))
        assertEquals("০৬:১৫", WidgetState.formatHm(e, "HH:mm", "bn"))
    }
}
