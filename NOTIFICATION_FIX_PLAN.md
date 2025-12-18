# Jamaat Time Notification Fix Plan

## Overview
Fix the jamaat time notification system to ensure notifications fire at the correct times regardless of user's device timezone, and resolve scheduling inconsistencies.

---

## Issues to Fix (Priority Order)

### 1. CRITICAL: Timezone Handling Bug
**File:** `lib/services/notification_service.dart` (lines 397-404)

**Problem:** Jamaat times are created in `Asia/Dhaka` timezone but compared with local device time. Users outside Bangladesh get wrong notification times.

**Fix:**
- Ensure consistent timezone handling throughout the notification scheduling
- Convert all times to the same timezone context before comparison
- Use `TZDateTime.now(tz.getLocation('Asia/Dhaka'))` for comparisons instead of `DateTime.now()`

---

### 2. MEDIUM: City Switch Doesn't Reschedule Notifications
**File:** `lib/screens/home_screen.dart` (line 616)

**Problem:** When user changes city, new jamaat times are fetched but old notifications remain scheduled.

**Fix:**
- Add notification rescheduling call in the city change handler
- Cancel existing notifications before scheduling new ones
- Set `_notificationsScheduled = false` before fetching new city data

---

### 3. MEDIUM: Maghrib Jamaat Time Inconsistency
**Files:**
- `lib/utils/jamaat_time_utility.dart` (lines 43-58)
- `lib/screens/home_screen.dart` (lines 532-544)

**Problem:** Maghrib jamaat is calculated locally (prayer time + offset) while other jamaat times come from Firebase, causing timezone inconsistencies.

**Fix:**
- Ensure Maghrib calculation uses consistent timezone handling
- Apply the same timezone conversion logic as other jamaat times
- Consider storing Maghrib offsets in Firebase for consistency

---

### 4. MEDIUM: Missing Error Handling for Time Parsing
**File:** `lib/services/notification_service.dart` (lines 387-407)

**Problem:** Malformed time strings fail silently without logging.

**Fix:**
- Add try-catch around time parsing
- Add validation for hour (0-23) and minute (0-59) ranges
- Log warnings for invalid time formats
- Skip invalid entries gracefully without crashing

---

### 5. LOW: Date Comparison Near Midnight
**File:** `lib/services/notification_service.dart` (lines 573-584)

**Problem:** Converting `TZDateTime` to regular `DateTime` strips timezone info, causing issues near midnight.

**Fix:**
- Keep all comparisons in `TZDateTime` format
- Use `tz.TZDateTime.now(location)` for consistent comparison
- Remove unnecessary conversion to regular `DateTime`

---

## Implementation Steps

### Step 1: Fix Timezone Handling in Notification Service
1. Create a helper method to get current time in Dhaka timezone
2. Update `scheduleJamaatNotifications()` to use consistent timezone
3. Update time comparison logic to compare TZDateTime objects directly

### Step 2: Fix City Switch Rescheduling
1. Locate city change handler in `home_screen.dart`
2. Add call to cancel existing notifications
3. Add call to reschedule notifications with new city's jamaat times

### Step 3: Fix Maghrib Calculation
1. Review `jamaat_time_utility.dart` offset calculation
2. Ensure Maghrib time uses same timezone as other prayers
3. Test with different device timezones

### Step 4: Add Error Handling
1. Wrap time parsing in try-catch blocks
2. Add validation for parsed values
3. Add debug logging for invalid times

### Step 5: Fix Midnight Comparison
1. Remove `notifyTimeRegular` conversion
2. Compare `TZDateTime` objects directly
3. Use `tz.TZDateTime.now()` instead of `DateTime.now()`

---

## Files to Modify

| File | Changes |
|------|---------|
| `lib/services/notification_service.dart` | Timezone fixes, error handling, midnight comparison |
| `lib/screens/home_screen.dart` | City switch rescheduling |
| `lib/utils/jamaat_time_utility.dart` | Maghrib timezone consistency |

---

## Testing Recommendations

1. Test with device timezone set to different zones (UTC, UTC+5, UTC+6)
2. Test city switching and verify new notifications are scheduled
3. Test near midnight to verify edge case handling
4. Test with malformed jamaat times in Firebase to verify error handling
