# Timing Mismatch Analysis — Sehri, Iftar & Main Prayer Cards

**Status:** PAUSED — waiting for user screenshot when 20-30 second mismatch is visible
**Date:** 2026-02-27

---

## Problem

The Sehri card, Iftar card, and main prayer countdown card show remaining times that can differ by 20-30 seconds. Manual verification (clock + remaining ≠ prayer table) also shows a mismatch.

## What's been verified so far

### From the device (Samsung A52, Feb 27, 07:12)

| Card | Countdown | Target | Table Time | Discrepancy |
|------|-----------|--------|------------|-------------|
| Sehri | 21:54:49 | ~05:07:01 tomorrow | 05:07 | ~1 second |
| Iftar | 10:47:48 | ~18:00:00 today | 18:00 | ~0 seconds |

At the time of testing, only ~1 second discrepancy was visible. The main card showed "Coming Dahwa-e-kubrah" (no countdown), so all three couldn't be compared simultaneously. **The user will take a screenshot when the mismatch is visible (likely after Isha or between Asr and Maghrib).**

---

## Confirmed Bugs (from code analysis)

### Bug 1 — `resolveNextOccurrence` projects today's time onto tomorrow

**File:** `lib/widgets/sahri_iftar_widget.dart:49-58`

When a prayer has passed today, the Sehri/Iftar card builds "tomorrow's" target by copying today's HH:MM:SS to tomorrow's date — **no recalculation via adhan**.

```dart
// After prayer passes:
final tomorrow = now.add(const Duration(days: 1));
final localTarget = targetTime.toLocal();
return DateTime(
  tomorrow.year, tomorrow.month, tomorrow.day,
  localTarget.hour,    // ← TODAY's prayer hour
  localTarget.minute,  // ← TODAY's prayer minute
  localTarget.second,  // ← TODAY's prayer second
);  // NO adhan recalculation
```

But `PrayerCountdownWidget` (`lib/widgets/prayer_countdown_widget.dart:180-188`) **correctly recalculates** tomorrow's prayer:

```dart
final tomorrowPrayerTimes = PrayerTimes(
  coordinates: coords,
  date: tomorrow,
  calculationParameters: widget.calculationParams!,
  precision: true,   // ← actual astronomical recalculation
);
final tomorrowFajr = tomorrowPrayerTimes.fajr;
```

**Impact:** After Isha, both cards count to "tomorrow's Fajr". The Sehri card uses a stale projection; the main card recalculates. The day-over-day change in Fajr (20-90 seconds depending on season) creates the mismatch. Near the equinox (Feb/Mar), Fajr shifts faster.

### Bug 2 — `precision: true` creates hidden seconds in prayer times

**Source:** adhan_dart library (`lib/src/DateUtils.dart:15-18`)

```dart
roundedMinute(DateTime date, {bool precision = true}) {
  if (precision) return date;   // Returns raw DateTime WITH seconds
  // Otherwise rounds to nearest minute
}
```

All `PrayerTimes()` calls in the app use `precision: true` (`home_screen.dart:307`, `prayer_countdown_widget.dart:184`). This gives prayer times like `05:07:32.847` instead of `05:07:00.000`.

But the prayer table displays `HH:mm` format (`home_screen.dart:701`):
```dart
DateFormat('HH:mm').format(t.toLocal())  // Shows "05:07", hides ":32"
```

The countdown widgets correctly count to the full-precision time (with seconds), but the table hides them. When manually verifying, the seconds create a 0-59 second discrepancy.

**On Feb 27, the precision seconds were close to 0 for most prayers, so the mismatch was minimal.**

### Bug 3 — Live clock updates every 60 seconds

**File:** `lib/widgets/live_clock_widget.dart:47`

```dart
_timer = Timer.periodic(const Duration(seconds: 60), (timer) { ... });
```

Shows `HH:mm` format, can be up to 59 seconds stale. Makes manual verification unreliable.

### Bug 4 — Independent timers (minor, ≤1 second)

Sehri/Iftar: `sahri_iftar_widget.dart:242` — own `Timer.periodic(seconds: 1)`
Main card: `prayer_countdown_widget.dart:59` — own `Timer.periodic(seconds: 1)`

Started at different wall-clock moments. At most ≤1 second drift.

---

## Proposed Fixes

### Fix 1 — Normalize prayer times to whole minutes (PRIMARY)

In `home_screen.dart` `_updatePrayerTimes()`, after getting prayer times from adhan, truncate each to the minute (zero out seconds/milliseconds) before storing in `times` map.

**OR:** Change `precision: true` to `precision: false` in all `PrayerTimes()` calls — adhan_dart will round to the nearest minute automatically.

**Effect:** Prayer table display and countdowns will be perfectly aligned. No hidden seconds.

### Fix 2 — Fix `resolveNextOccurrence` to recalculate via adhan

Add `Coordinates` and `CalculationParameters` to `SahriIftarWidget`. When the prayer has passed, use `PrayerTimes(date: tomorrow)` to get tomorrow's actual time (same pattern as `PrayerCountdownWidget:180-188`).

### Fix 3 — Update live clock

Change timer to `Duration(seconds: 1)` and/or show `HH:mm:ss` format.

---

## Files involved

| File | What to change |
|------|---------------|
| `lib/screens/home_screen.dart` | Truncate prayer times to minute in `_updatePrayerTimes()` (~line 309-314) |
| `lib/widgets/sahri_iftar_widget.dart` | Add coords/params, fix `resolveNextOccurrence` (~line 40-58) |
| `lib/widgets/prayer_countdown_widget.dart` | Already correct (reference for fix pattern) |
| `lib/widgets/live_clock_widget.dart` | Change timer to 1 second (~line 47) |

---

## TODO

- [ ] User to take screenshot when 20-30 second mismatch is visible (after Isha or between Asr-Maghrib)
- [ ] Verify whether the mismatch matches Bug 1 (resolveNextOccurrence) or Bug 2 (precision seconds) or both
- [ ] Implement fixes
