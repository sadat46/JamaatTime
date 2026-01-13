# Comprehensive Fix Plan for Jamaat Time App

## Executive Summary
This document details fixes for three issues: timezone hardcoding, manual entry not updating, and unnecessary home screen refreshes.

---

## Issue 1: Incorrect Prayer Times (Global Compatibility)

### Problem
Prayer times display incorrectly when the app is used outside Bangladesh (e.g., in Makkah) because the timezone is hardcoded to "Asia/Dhaka".

### Root Cause Analysis
1. **`lib/core/constants.dart:7`** - Hardcoded `defaultTimeZone = 'Asia/Dhaka'`
2. **`lib/main.dart:28`** - Forces global timezone: `tz.setLocalLocation(tz.getLocation(AppConstants.defaultTimeZone))`
3. **`lib/screens/home_screen.dart:513-517`** - `_calculateMaghribJamaatTime()` uses `tz.getLocation('Asia/Dhaka')`
4. **`lib/screens/home_screen.dart:525`** - `_computePrayerTableData()` uses `tz.getLocation('Asia/Dhaka')`
5. **`lib/widgets/prayer_time_table.dart:77-80`** - Uses hardcoded `tz.getLocation('Asia/Dhaka')`

### Fix Plan

#### Fix 1.1: Modify `lib/core/constants.dart`
**Action:** Comment out or remove the default timezone constant.
```dart
// Line 7 - REMOVE or comment out:
// static const String defaultTimeZone = 'Asia/Dhaka';
```

#### Fix 1.2: Modify `lib/main.dart`
**Action:** Remove the line that forces the app's location to the default timezone.
```dart
// Line 28 - REMOVE or comment out:
// tz.setLocalLocation(tz.getLocation(AppConstants.defaultTimeZone));
```

#### Fix 1.3: Modify `lib/screens/home_screen.dart` - `_calculateMaghribJamaatTime()`
**Location:** Lines 506-520
**Action:** Replace hardcoded Dhaka timezone with device local time.

**Current Code:**
```dart
String _calculateMaghribJamaatTime() {
  final maghribPrayerTime = times['Maghrib'];
  if (maghribPrayerTime != null && selectedCity != null) {
    final offset = _getMaghribOffset(selectedCity!);
    final dhakaLocation = tz.getLocation('Asia/Dhaka');
    final maghribInDhaka = tz.TZDateTime.from(maghribPrayerTime, dhakaLocation);
    final maghribJamaatTime = maghribInDhaka.add(Duration(minutes: offset));
    return DateFormat('HH:mm').format(maghribJamaatTime);
  }
  return '-';
}
```

**New Code:**
```dart
String _calculateMaghribJamaatTime() {
  final maghribPrayerTime = times['Maghrib'];
  if (maghribPrayerTime != null && selectedCity != null) {
    final offset = _getMaghribOffset(selectedCity!);
    // Use device local time instead of hardcoded Dhaka timezone
    final maghribLocal = maghribPrayerTime.toLocal();
    final maghribJamaatTime = maghribLocal.add(Duration(minutes: offset));
    return DateFormat('HH:mm').format(maghribJamaatTime);
  }
  return '-';
}
```

#### Fix 1.4: Modify `lib/screens/home_screen.dart` - `_computePrayerTableData()`
**Location:** Lines 523-590
**Action:** Replace hardcoded Dhaka timezone with `.toLocal()`.

**Current Code (lines 524-544):**
```dart
void _computePrayerTableData() {
  final currentPrayer = _getCurrentPrayerName();
  final dhakaLocation = tz.getLocation('Asia/Dhaka');
  // ...
  _prayerTableData = prayerNames.map((name) {
    final t = times[name];
    final timeStr = t != null
        ? DateFormat('HH:mm').format(
            tz.TZDateTime.from(t, dhakaLocation),
          )
        : '-';
    // ...
  }).toList();
}
```

**New Code:**
```dart
void _computePrayerTableData() {
  final currentPrayer = _getCurrentPrayerName();
  // REMOVED: final dhakaLocation = tz.getLocation('Asia/Dhaka');
  // ...
  _prayerTableData = prayerNames.map((name) {
    final t = times[name];
    // Use .toLocal() instead of hardcoded timezone
    final timeStr = t != null
        ? DateFormat('HH:mm').format(t.toLocal())
        : '-';
    // ...
  }).toList();
}
```

#### Fix 1.5: Modify `lib/widgets/prayer_time_table.dart`
**Location:** Lines 75-82
**Action:** Replace hardcoded Dhaka timezone with `.toLocal()`.

**Current Code:**
```dart
final t = times[name];
final timeStr = t != null
    ? DateFormat('HH:mm').format(
        tz.TZDateTime.from(
          t,
          tz.getLocation('Asia/Dhaka'),
        ),
      )
    : '-';
```

**New Code:**
```dart
final t = times[name];
final timeStr = t != null
    ? DateFormat('HH:mm').format(t.toLocal())
    : '-';
```

---

## Issue 2: Manual Data Entry Not Displaying

### Problem
Edits made in the Admin Panel do not appear on the Home Screen.

### Root Cause Analysis
1. **Caching Issue:** `JamaatService` caches data for 30 minutes (`lib/services/jamaat_service.dart:17`). When Admin Panel updates, the cache isn't cleared.

2. **Schema Mismatch:**
   - Admin Panel Edit/Save writes directly to document root: `{fajr: "05:00"}` (line 962-971 in admin_jamaat_panel.dart)
   - JamaatService reads from nested path: `data['times']` (line 112 in jamaat_service.dart)

### Fix Plan

#### Fix 2.1: Add `updateSingleJamaatTime` method to `lib/services/jamaat_service.dart`
**Location:** Add after line 156 (after `clearCache()` method)
**Action:** Add a new method that updates with correct schema and clears cache.

**New Method to Add:**
```dart
/// Update a single prayer's jamaat time with proper schema and cache clearing
Future<void> updateSingleJamaatTime({
  required String city,
  required DateTime date,
  required String prayerName,
  required String time,
}) async {
  final cityKey = city.toLowerCase().replaceAll(' ', '_');
  final dateString = _formatDate(date);

  // 1. Clear cache for this city/date
  final cacheKey = _getCacheKey(city, date);
  _cache.remove(cacheKey);

  // 2. Save with correct schema (nested under 'times')
  await _firestore
      .collection('jamaat_times')
      .doc(cityKey)
      .collection('daily_times')
      .doc(dateString)
      .set({
        'times': {prayerName.toLowerCase(): time},
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  developer.log(
    'Updated $prayerName time for $city on $dateString: $time',
    name: 'JamaatService',
  );
}
```

#### Fix 2.2: Modify `lib/screens/admin_jamaat_panel.dart` - Edit/Save button
**Location:** Lines 962-984 (inside the Save button's `onPressed` callback)
**Action:** Replace direct Firestore call with the new service method.

**Current Code:**
```dart
try {
  final data = {p.toLowerCase(): formatted};
  final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
  final cityKey = _selectedCity.toLowerCase().replaceAll(' ', '_');
  await FirebaseFirestore.instance
      .collection('jamaat_times')
      .doc(cityKey)
      .collection('daily_times')
      .doc(dateString)
      .set(data, SetOptions(merge: true));
  // ...
}
```

**New Code:**
```dart
try {
  await _jamaatService.updateSingleJamaatTime(
    city: _selectedCity,
    date: _selectedDate,
    prayerName: p,
    time: formatted,
  );
  // ...
}
```

---

## Issue 3: Home Screen Refresh on Navigation

### Problem
The Home Screen reloads (fetching location and data) every time the user switches tabs.

### Root Cause Analysis
**`lib/main.dart:110`** - The body uses direct indexing which causes widget recreation:
```dart
body: _screens[_selectedIndex],
```
When `_selectedIndex` changes, Flutter rebuilds the widget at that index from scratch.

### Fix Plan

#### Fix 3.1: Modify `lib/main.dart` - Use IndexedStack
**Location:** Line 110 (inside `_MainScaffoldState.build()`)
**Action:** Wrap screens with `IndexedStack` to keep all screens alive.

**Current Code:**
```dart
return Scaffold(
  body: _screens[_selectedIndex],
  bottomNavigationBar: BottomNavigationBar(
    // ...
  ),
);
```

**New Code:**
```dart
return Scaffold(
  body: IndexedStack(
    index: _selectedIndex,
    children: _screens,
  ),
  bottomNavigationBar: BottomNavigationBar(
    // ...
  ),
);
```

---

## Implementation Order

1. **Issue 3 (IndexedStack)** - Quick fix, immediate UX improvement
2. **Issue 2 (Manual Entry)** - Add service method, update admin panel
3. **Issue 1 (Timezone)** - Most impactful, requires testing across locations

## Testing Checklist

### Issue 1 Testing
- [ ] Verify prayer times display correctly in Bangladesh timezone
- [ ] Test with device timezone set to different zones (Makkah, London, New York)
- [ ] Verify Maghrib jamaat calculation works correctly

### Issue 2 Testing
- [ ] Edit a prayer time in Admin Panel
- [ ] Verify it appears immediately on Home Screen
- [ ] Verify cache is properly cleared after edit

### Issue 3 Testing
- [ ] Switch between tabs multiple times
- [ ] Verify Home Screen does not reload/refetch data
- [ ] Verify clock continues running smoothly

## Files to Modify Summary

| File | Issue | Changes |
|------|-------|---------|
| `lib/core/constants.dart` | 1 | Remove/comment `defaultTimeZone` |
| `lib/main.dart` | 1, 3 | Remove timezone forcing, add IndexedStack |
| `lib/screens/home_screen.dart` | 1 | Use `.toLocal()` instead of hardcoded timezone |
| `lib/widgets/prayer_time_table.dart` | 1 | Use `.toLocal()` instead of hardcoded timezone |
| `lib/services/jamaat_service.dart` | 2 | Add `updateSingleJamaatTime()` method |
| `lib/screens/admin_jamaat_panel.dart` | 2 | Use new service method for saving |
