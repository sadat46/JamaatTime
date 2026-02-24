# Implementation Plan: Sahri/Iftar Times & Forbidden Prayer Windows

**Version:** 1.0
**Date:** 2026-01-18
**Status:** Ready for Implementation

---

## 1. Executive Summary

This document outlines the implementation plan for adding two features to the Jamaat Time application:

1. **Sahri & Iftar Times** - Display Sahri end time and Iftar start time with live countdown
2. **Forbidden Prayer Windows** - Display the three periods when Salah is prohibited

These features will enhance the app's utility during Ramadan and provide important guidance for daily prayers.

---

## 2. Requirements Specification

### 2.1 Sahri & Iftar Feature

| Requirement | Description |
|-------------|-------------|
| Sahri End Time | Display time when Sahri ends (equals Fajr start time) |
| Iftar Start Time | Display time when Iftar begins (equals Maghrib start time) |
| Live Countdown | Show countdown with seconds (HH:MM:SS) when approaching Fajr or Maghrib |
| Contextual Labels | Display "Sahri ends in: X" before Fajr, "Iftar in: X" before Maghrib |

### 2.2 Forbidden Prayer Windows Feature

| Window | Start Time | End Time | Duration |
|--------|------------|----------|----------|
| **Sunrise** | At Sunrise | Sunrise + 15 minutes | ~15 min |
| **Zawal (Solar Zenith)** | Dhuhr - 5 minutes | Dhuhr + 5 minutes | ~10 min |
| **Sunset** | Maghrib - 15 minutes | At Maghrib | ~15 min |

**Note:** These are the times when performing Salah is makruh (disliked/prohibited).

---

## 3. Current Architecture Analysis

### 3.1 Relevant Files

| File | Purpose | Modifications Required |
|------|---------|----------------------|
| `lib/services/prayer_calculation_service.dart` | Prayer time calculations | Add forbidden windows calculation |
| `lib/screens/home_screen.dart` | Main UI, table data preparation | Add new rows for Sahri/Iftar/Forbidden |
| `lib/widgets/prayer_countdown_widget.dart` | Live countdown display | Add Sahri/Iftar contextual labels |

### 3.2 Data Flow

```
PrayerCalculationService
        │
        ▼
    PrayerTimes (adhan_dart)
        │
        ▼
    HomeScreen._computePrayerTableData()
        │
        ▼
    List<PrayerRowData>
        │
        ▼
    Table Widget (UI)
```

### 3.3 Current PrayerRowData Model

```dart
// Location: lib/screens/home_screen.dart:26-38
class PrayerRowData {
  final String name;
  final String timeStr;
  final String jamaatStr;
  final bool isCurrent;
}
```

---

## 4. Technical Design

### 4.1 Enhanced PrayerRowData Model

```dart
/// Row type for conditional styling
enum PrayerRowType {
  prayer,      // Standard prayer times (Fajr, Dhuhr, etc.)
  info,        // Informational rows (Sunrise, Dahwah-e-kubrah)
  sahriIftar,  // Sahri/Iftar rows (amber styling)
  forbidden,   // Forbidden time windows (red styling)
}

class PrayerRowData {
  final String name;
  final String timeStr;
  final String jamaatStr;
  final bool isCurrent;
  final PrayerRowType type;
  final String? endTimeStr;  // For forbidden windows (shows range)

  const PrayerRowData({
    required this.name,
    required this.timeStr,
    required this.jamaatStr,
    required this.isCurrent,
    this.type = PrayerRowType.prayer,
    this.endTimeStr,
  });
}
```

### 4.2 Forbidden Windows Data Structure

```dart
/// Represents a forbidden prayer time window
class ForbiddenWindow {
  final String name;
  final DateTime start;
  final DateTime end;

  const ForbiddenWindow({
    required this.name,
    required this.start,
    required this.end,
  });

  /// Check if current time falls within this forbidden window
  bool isActive(DateTime now) {
    return now.isAfter(start) && now.isBefore(end);
  }

  /// Format as time range string (e.g., "05:45 - 06:00")
  String toRangeString() {
    final startStr = DateFormat('HH:mm').format(start.toLocal());
    final endStr = DateFormat('HH:mm').format(end.toLocal());
    return '$startStr - $endStr';
  }
}
```

### 4.3 Service Layer Addition

```dart
// Add to: lib/services/prayer_calculation_service.dart

/// Calculate forbidden prayer time windows
/// Returns list of ForbiddenWindow objects for the given prayer times
List<ForbiddenWindow> calculateForbiddenWindows(PrayerTimes pt) {
  final windows = <ForbiddenWindow>[];

  // 1. Sunrise Window: From sunrise for ~15 minutes
  if (pt.sunrise != null) {
    windows.add(ForbiddenWindow(
      name: 'After Sunrise',
      start: pt.sunrise!,
      end: pt.sunrise!.add(const Duration(minutes: 15)),
    ));
  }

  // 2. Zawal Window: ~5 minutes before and after solar zenith (Dhuhr)
  if (pt.dhuhr != null) {
    windows.add(ForbiddenWindow(
      name: 'Zawal (Zenith)',
      start: pt.dhuhr!.subtract(const Duration(minutes: 5)),
      end: pt.dhuhr!.add(const Duration(minutes: 5)),
    ));
  }

  // 3. Sunset Window: ~15 minutes before Maghrib
  if (pt.maghrib != null) {
    windows.add(ForbiddenWindow(
      name: 'Before Sunset',
      start: pt.maghrib!.subtract(const Duration(minutes: 15)),
      end: pt.maghrib!,
    ));
  }

  return windows;
}
```

### 4.4 Countdown Widget Logic Update

```dart
// Update in: lib/widgets/prayer_countdown_widget.dart
// Method: _calculateCountdown() around line 91-113

// Replace the else block with Sahri/Iftar aware logic:
} else {
  // Today - show countdown with contextual labels
  final currentPeriod = _getCurrentPrayerPeriodName(now);
  final nextPrayer = _getNextPrayerName(now);
  final timeToNext = _getTimeToNextPrayer(now);
  progress = _calculateProgress(now);

  if (currentPeriod == 'Sunrise') {
    text = 'Coming Dahwa-e-kubrah';
    isSpecial = true;
  } else if (currentPeriod == 'Dahwah-e-kubrah') {
    text = 'Coming Dhuhr';
    isSpecial = true;
  } else {
    // Format as HH:MM:SS
    final hours = timeToNext.inHours;
    final minutes = timeToNext.inMinutes.remainder(60);
    final seconds = timeToNext.inSeconds.remainder(60);

    final countdown = timeToNext.isNegative
        ? '--:--:--'
        : '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    // Contextual labels for Sahri/Iftar
    String label;
    if (nextPrayer == 'Fajr') {
      label = 'Sahri ends in';
    } else if (nextPrayer == 'Maghrib') {
      label = 'Iftar in';
    } else {
      label = '$nextPrayer in';
    }

    text = '$label: $countdown';
    isSpecial = false;
  }
}
```

### 4.5 Table Data Preparation Update

```dart
// Update in: lib/screens/home_screen.dart
// Method: _computePrayerTableData()

void _computePrayerTableData() {
  final currentPrayer = _getCurrentPrayerName();
  final List<PrayerRowData> tableData = [];

  // === SECTION 1: Main Prayer Times ===
  const prayerNames = [
    'Fajr',
    'Sunrise',
    'Dahwah-e-kubrah',
    'Dhuhr',
    'Asr',
    'Maghrib',
    'Isha',
  ];

  for (final name in prayerNames) {
    final t = times[name];
    final timeStr = t != null ? DateFormat('HH:mm').format(t.toLocal()) : '-';

    // Determine row type
    PrayerRowType type;
    if (name == 'Sunrise' || name == 'Dahwah-e-kubrah') {
      type = PrayerRowType.info;
    } else {
      type = PrayerRowType.prayer;
    }

    // Get jamaat time (existing logic)
    final jamaatStr = _getJamaatTimeForPrayer(name);

    tableData.add(PrayerRowData(
      name: name,
      timeStr: timeStr,
      jamaatStr: jamaatStr,
      isCurrent: name == currentPrayer,
      type: type,
    ));
  }

  // === SECTION 2: Sahri & Iftar ===
  final fajrTime = times['Fajr'];
  final maghribTime = times['Maghrib'];

  if (fajrTime != null) {
    tableData.add(PrayerRowData(
      name: 'Sahri Ends',
      timeStr: DateFormat('HH:mm').format(fajrTime.toLocal()),
      jamaatStr: '-',
      isCurrent: currentPrayer == 'Fajr',
      type: PrayerRowType.sahriIftar,
    ));
  }

  if (maghribTime != null) {
    tableData.add(PrayerRowData(
      name: 'Iftar Begins',
      timeStr: DateFormat('HH:mm').format(maghribTime.toLocal()),
      jamaatStr: '-',
      isCurrent: currentPrayer == 'Maghrib',
      type: PrayerRowType.sahriIftar,
    ));
  }

  // === SECTION 3: Forbidden Windows ===
  if (prayerTimes != null) {
    final forbiddenWindows = PrayerCalculationService.instance
        .calculateForbiddenWindows(prayerTimes!);

    for (final window in forbiddenWindows) {
      tableData.add(PrayerRowData(
        name: window.name,
        timeStr: window.toRangeString(),
        jamaatStr: 'Makruh',
        isCurrent: window.isActive(DateTime.now()),
        type: PrayerRowType.forbidden,
      ));
    }
  }

  _prayerTableData = tableData;
}
```

### 4.6 Table Row Styling

```dart
// Update in: lib/screens/home_screen.dart
// In the Table widget builder (around line 1146)

..._prayerTableData.map((row) => TableRow(
  decoration: _getRowDecoration(row, context),
  children: [
    // ... existing cell widgets
  ],
)),

// Add helper method:
BoxDecoration? _getRowDecoration(PrayerRowData row, BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  switch (row.type) {
    case PrayerRowType.forbidden:
      return BoxDecoration(
        color: isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50,
      );
    case PrayerRowType.sahriIftar:
      return BoxDecoration(
        color: isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade50,
      );
    case PrayerRowType.prayer:
    case PrayerRowType.info:
      if (row.isCurrent) {
        return BoxDecoration(
          color: isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade100,
        );
      }
      return null;
  }
}
```

---

## 5. Implementation Steps

### Phase 1: Model Updates

| Step | File | Action |
|------|------|--------|
| 1.1 | `home_screen.dart` | Add `PrayerRowType` enum before `PrayerRowData` class |
| 1.2 | `home_screen.dart` | Update `PrayerRowData` class with `type` and `endTimeStr` fields |

### Phase 2: Service Layer

| Step | File | Action |
|------|------|--------|
| 2.1 | `prayer_calculation_service.dart` | Add `ForbiddenWindow` class |
| 2.2 | `prayer_calculation_service.dart` | Add `calculateForbiddenWindows()` method |

### Phase 3: Home Screen Updates

| Step | File | Action |
|------|------|--------|
| 3.1 | `home_screen.dart` | Update `_computePrayerTableData()` to include Sahri/Iftar rows |
| 3.2 | `home_screen.dart` | Update `_computePrayerTableData()` to include forbidden window rows |
| 3.3 | `home_screen.dart` | Add `_getRowDecoration()` helper method |
| 3.4 | `home_screen.dart` | Update Table widget to use new decoration logic |

### Phase 4: Countdown Widget

| Step | File | Action |
|------|------|--------|
| 4.1 | `prayer_countdown_widget.dart` | Add `_getNextPrayerName()` helper method |
| 4.2 | `prayer_countdown_widget.dart` | Update `_calculateCountdown()` with Sahri/Iftar labels |

### Phase 5: Testing & Refinement

| Step | Action |
|------|--------|
| 5.1 | Test countdown displays "Sahri ends in" before Fajr |
| 5.2 | Test countdown displays "Iftar in" before Maghrib |
| 5.3 | Verify forbidden windows show correct time ranges |
| 5.4 | Test row styling (amber for Sahri/Iftar, red for forbidden) |
| 5.5 | Test dark mode styling |
| 5.6 | Test with different locations (Bangladesh, Saudi Arabia, GPS mode) |

---

## 6. UI/UX Specifications

### 6.1 Color Scheme

| Row Type | Light Mode | Dark Mode |
|----------|------------|-----------|
| Current Prayer | `Colors.green.shade100` | `Colors.green.shade900` @ 30% |
| Sahri/Iftar | `Colors.orange.shade50` | `Colors.orange.shade900` @ 30% |
| Forbidden | `Colors.red.shade50` | `Colors.red.shade900` @ 30% |
| Normal | No background | No background |

### 6.2 Table Layout

```
┌─────────────────┬─────────────┬─────────────┐
│ Prayer Name     │ Prayer Time │ Jamaat Time │
├─────────────────┼─────────────┼─────────────┤
│ Fajr            │ 05:12       │ 05:30       │  ← Green if current
│ Sunrise         │ 06:32       │ -           │
│ Dahwah-e-kubrah │ 11:52       │ -           │
│ Dhuhr           │ 12:12       │ 13:15       │
│ Asr             │ 15:45       │ 16:30       │
│ Maghrib         │ 17:52       │ 17:59       │
│ Isha            │ 19:12       │ 20:00       │
├─────────────────┼─────────────┼─────────────┤
│ Sahri Ends      │ 05:12       │ -           │  ← Amber background
│ Iftar Begins    │ 17:52       │ -           │  ← Amber background
├─────────────────┼─────────────┼─────────────┤
│ After Sunrise   │ 06:32-06:47 │ Makruh      │  ← Red background
│ Zawal (Zenith)  │ 12:07-12:17 │ Makruh      │  ← Red background
│ Before Sunset   │ 17:37-17:52 │ Makruh      │  ← Red background
└─────────────────┴─────────────┴─────────────┘
```

### 6.3 Countdown Display Examples

| Time Context | Display Text |
|--------------|--------------|
| Before Fajr | `Sahri ends in: 02:15:30` |
| Before Maghrib | `Iftar in: 01:45:22` |
| Before Dhuhr | `Dhuhr in: 00:30:15` |
| Before Asr | `Asr in: 03:20:45` |
| Before Isha | `Isha in: 01:10:05` |

---

## 7. Edge Cases & Considerations

### 7.1 Ramadan Detection

Currently, `_isRamadan()` in the service returns `false`. For full Ramadan support:
- Consider adding a Hijri calendar package (`hijri_calendar`)
- Or allow manual Ramadan mode toggle in settings

### 7.2 Location-Specific Adjustments

- Forbidden window durations may vary by scholarly opinion
- Consider making durations configurable in future versions

### 7.3 Midnight Boundary

- Handle countdown correctly when Fajr is after midnight
- Ensure Sahri countdown works for late-night users

---

## 8. Files Modified Summary

| File | Changes |
|------|---------|
| `lib/services/prayer_calculation_service.dart` | +`ForbiddenWindow` class, +`calculateForbiddenWindows()` |
| `lib/screens/home_screen.dart` | +`PrayerRowType` enum, update `PrayerRowData`, update `_computePrayerTableData()`, +`_getRowDecoration()` |
| `lib/widgets/prayer_countdown_widget.dart` | Update `_calculateCountdown()`, +`_getNextPrayerName()` |

---

## 9. Acceptance Criteria

- [ ] Sahri end time displays correctly (matches Fajr time)
- [ ] Iftar start time displays correctly (matches Maghrib time)
- [ ] Countdown shows "Sahri ends in: HH:MM:SS" when next prayer is Fajr
- [ ] Countdown shows "Iftar in: HH:MM:SS" when next prayer is Maghrib
- [ ] Three forbidden windows display with time ranges
- [ ] Forbidden windows show "Makruh" in Jamaat column
- [ ] Sahri/Iftar rows have amber background
- [ ] Forbidden rows have red/warning background
- [ ] Styling works correctly in both light and dark modes
- [ ] All existing functionality remains intact

---

## 10. Rollback Plan

If issues arise during implementation:
1. Revert changes to the three modified files
2. Run `flutter clean && flutter pub get`
3. Verify app builds and runs correctly

---

**Document Prepared By:** Claude AI
**Ready for Implementation:** Yes
