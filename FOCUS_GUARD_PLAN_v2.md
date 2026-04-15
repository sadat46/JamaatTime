# Focus Guard — Audited Implementation Plan v2
**Project:** Jamaat Time — Focus Guard (Shorts/Reels Blocker)
**Target stack:** Flutter + Native Android (Kotlin)
**Audit date:** 2026-04-14

---

## Audit Summary

### Issues found in v1

1. **Architecture mismatch.** The plan proposes `lib/features/focus_guard/{domain,data,application,presentation}/` — a clean-architecture pattern the app does NOT use. The existing codebase is flat: `lib/models/`, `lib/services/`, `lib/screens/`, `lib/widgets/`, `lib/data/`. Introducing a second architecture creates confusion and maintenance burden. **Fix:** follow existing conventions.

2. **Over-scoped MVP.** 14 phases, 30+ files, 4 detector stubs, prayer-aware blocking, history/analytics — all before shipping YouTube Shorts. This is 6+ weeks of work with high risk of abandonment. **Fix:** cut to 3 milestones with hard "ship gate" after YouTube-only MVP.

3. **Google Play AccessibilityService policy not addressed.** Google actively reviews and can reject apps using AccessibilityService for non-accessibility purposes. The plan has zero mention of compliance strategy, privacy policy requirements, or the alternative `UsageStatsManager` approach. **Fix:** add policy compliance section.

4. **No munajat deterrent on disable.** User requirement: when toggling Focus Guard OFF, a random munajat from the existing 47 entries must display for 15 seconds before the OFF action is enabled. This is missing entirely. **Fix:** add as a core feature in the settings UI phase.

5. **Missing Android version handling.** Overlay behavior differs on Android 8 vs 10 vs 12 vs 13+. The plan doesn't specify `TYPE_APPLICATION_OVERLAY` vs deprecated types, or `canDrawOverlays()` checks. **Fix:** add compatibility matrix.

6. **Native settings store is premature.** For MVP the settings are simple (enabled: bool, apps: list). Using Flutter's existing `SharedPreferences` (already in pubspec) and syncing to native via MethodChannel on change is simpler than building a parallel native DataStore. **Fix:** simplify storage to SharedPreferences + channel sync.

7. **No integration with existing prayer infrastructure.** The plan says "sync next-prayer timestamp to native" but doesn't specify HOW to integrate with `PrayerCalculationService` / `PrayerTimeEngine` which already computes all prayer times. **Fix:** specify exact integration points.

8. **Battery optimization section is hand-wavy.** Just says "show for devices where background reliability is poor." AccessibilityService actually doesn't need battery optimization exemptions (it's a system-managed service). The real concern is OEM-specific task killers. **Fix:** clarify what actually needs handling.

9. **Missing the back-press action implementation detail.** `performGlobalAction(GLOBAL_ACTION_BACK)` can fail or be intercepted. YouTube specifically handles back differently in Shorts vs regular video. Plan doesn't address fallback. **Fix:** add fallback strategy.

10. **No versioning or feature flag.** A feature this invasive (AccessibilityService) needs a kill switch. **Fix:** add remote feature flag consideration.

---

## Corrected Plan

### File placement (matches existing codebase)

```
lib/
  models/focus_guard_settings.dart
  services/focus_guard_service.dart
  screens/focus_guard_screen.dart
  widgets/focus_guard/
    munajat_disable_dialog.dart
    permission_setup_card.dart
    app_toggle_card.dart

android/app/src/main/kotlin/com/example/jamaat_time/
  focusguard/
    FocusGuardAccessibilityService.kt
    FocusGuardOverlayService.kt
    FocusGuardDetector.kt
    FocusGuardChannel.kt
  MainActivity.kt  (existing, add channel registration)

android/app/src/main/res/
  xml/focus_guard_accessibility_config.xml
  layout/focus_guard_overlay.xml
```

---

## Milestone 1 — YouTube Shorts blocker (MVP)

### 1.1 Domain model

**File:** `lib/models/focus_guard_settings.dart`

```dart
class FocusGuardSettings {
  final bool enabled;
  final Map<String, bool> blockedApps; // {'youtube': true, 'instagram': false, ...}
  final int tempAllowMinutes;          // last-used quick-allow duration

  // toJson / fromJson / copyWith
}
```

Keep it minimal. No prayer-aware rules, no time windows, no confidence scores. Those are Milestone 3.

**Done when:** model serializes round-trip through SharedPreferences.

---

### 1.2 Flutter service

**File:** `lib/services/focus_guard_service.dart`

Responsibilities:
- Load/save settings via SharedPreferences
- Check permission status via MethodChannel
- Push settings to native side on every save
- Open system Accessibility / Overlay settings intents
- Provide random munajat for disable dialog (imports `allMonajatList` from existing `data/monajat_data.dart`)

Key methods:
```dart
Future<FocusGuardSettings> loadSettings()
Future<void> saveSettings(FocusGuardSettings settings)
Future<Map<String, bool>> getPermissionStatus()
  // returns {'accessibility': bool, 'overlay': bool}
Future<void> openAccessibilitySettings()
Future<void> openOverlaySettings()
Future<void> syncSettingsToNative(FocusGuardSettings settings)
MonajatModel getRandomMunajat()
  // returns allMonajatList[Random().nextInt(allMonajatList.length)]
```

**Done when:** settings persist across app restart; channel stubs return mock values.

---

### 1.3 Munajat disable dialog

**File:** `lib/widgets/focus_guard/munajat_disable_dialog.dart`

This is the spiritual deterrent that fires when the user tries to toggle Focus Guard OFF.

**Behavior:**
1. User taps the master toggle to OFF
2. Instead of immediate disable, a modal bottom sheet / dialog appears
3. A random munajat is selected from `allMonajatList` (47 entries)
4. Dialog shows: Arabic text, pronunciation, meaning (reuse styling from `MonajatDetailScreen`)
5. A 15-second countdown timer is visible ("Please reflect for 15 seconds...")
6. The "Disable Guard" button is greyed out / disabled during countdown
7. After 15 seconds, the button becomes active with a warning color (red/orange)
8. User can dismiss (cancel) at any time — guard stays ON
9. If user taps disabled button after countdown: guard is turned off, settings saved

**Implementation:**
```dart
class MunajatDisableDialog extends StatefulWidget {
  final MonajatModel monajat;
  final VoidCallback onConfirmDisable;

  // ...
}

class _MunajatDisableDialogState extends State<MunajatDisableDialog> {
  int _remainingSeconds = 15;
  Timer? _timer;
  bool get _canDisable => _remainingSeconds <= 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() { _remainingSeconds--; });
      if (_remainingSeconds <= 0) t.cancel();
    });
  }

  // Build: show monajat arabic + meaning + countdown + disabled/enabled button
}
```

**Done when:** tapping toggle OFF shows dialog, countdown works, cancel preserves ON state, confirm after 15s disables guard.

---

### 1.4 Focus Guard settings screen

**File:** `lib/screens/focus_guard_screen.dart`

Single screen with:
- Permission status cards (Accessibility + Overlay) with setup buttons
- Master toggle (triggers munajat dialog on OFF)
- App toggles: YouTube (enabled for MVP), Instagram/Facebook/TikTok (shown but disabled, "Coming soon")
- Quick-allow duration selector (5 / 10 / 15 min)

Navigation entry point: add to existing app's settings or home screen nav.

**Done when:** screen renders, permissions open correct system settings, toggle triggers munajat dialog.

---

### 1.5 Android manifest updates

**File:** `android/app/src/main/AndroidManifest.xml`

Add inside `<manifest>`:
```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
```

Add inside `<application>`:
```xml
<service
    android:name=".focusguard.FocusGuardAccessibilityService"
    android:exported="false"
    android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE">
    <intent-filter>
        <action android:name="android.accessibilityservice.AccessibilityService"/>
    </intent-filter>
    <meta-data
        android:name="android.accessibilityservice"
        android:resource="@xml/focus_guard_accessibility_config"/>
</service>
```

**Done when:** app installs; "JamaatTime Focus Guard" appears in Android Accessibility settings.

---

### 1.6 Accessibility config XML

**File:** `android/app/src/main/res/xml/focus_guard_accessibility_config.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeWindowStateChanged|typeWindowContentChanged"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:notificationTimeout="300"
    android:packageNames="com.google.android.youtube"
    android:canRetrieveWindowContent="true"
    android:settingsActivity="com.example.jamaat_time.MainActivity"
    android:description="@string/focus_guard_description"/>
```

Start with YouTube ONLY in `packageNames`. Add more packages later by updating config programmatically or by removing the filter and doing package checks in code.

**Important:** add `<string name="focus_guard_description">` to `res/values/strings.xml` explaining WHY the accessibility permission is needed — this is required for Google Play review.

---

### 1.7 MethodChannel bridge

**File:** `android/app/src/main/kotlin/.../focusguard/FocusGuardChannel.kt`

Methods exposed to Flutter:
- `isAccessibilityEnabled` → check if service is running
- `isOverlayEnabled` → check `Settings.canDrawOverlays()`
- `openAccessibilitySettings` → launch intent
- `openOverlaySettings` → launch `ACTION_MANAGE_OVERLAY_PERMISSION`
- `updateSettings` → receive JSON from Flutter, store in SharedPreferences, notify running service
- `getBlockHistory` → return recent block events (Milestone 2)

**File:** `android/app/src/main/kotlin/.../MainActivity.kt`

Add channel registration in `configureFlutterEngine` alongside existing `jamaat_time/screen_awake` channel:
```kotlin
FocusGuardChannel(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
```

**Done when:** Flutter can query real permission status and open system settings.

---

### 1.8 AccessibilityService + YouTube detector

**File:** `android/app/src/main/kotlin/.../focusguard/FocusGuardAccessibilityService.kt`

Single file for MVP. No separate detector engine yet — keep it simple.

```kotlin
class FocusGuardAccessibilityService : AccessibilityService() {

    // Read settings from SharedPreferences
    // On event:
    //   1. Check if enabled + youtube is blocked
    //   2. Check package == "com.google.android.youtube"
    //   3. Check if temporarily allowed (expiry timestamp in prefs)
    //   4. Detect Shorts surface via multi-signal:
    //      - TYPE_WINDOW_STATE_CHANGED with Shorts-specific class names
    //      - Node tree text search for "Shorts" tab selected state
    //      - Vertical ViewPager detection (Shorts viewer)
    //   5. If detected + confidence >= threshold:
    //      - performGlobalAction(GLOBAL_ACTION_BACK)
    //      - Show overlay via FocusGuardOverlayService
    //   6. Debounce: ignore repeat events for 2 seconds after action

    // Debounce state
    private var lastActionTimestamp = 0L
    private val debounceMs = 2000L
}
```

**YouTube Shorts detection signals (in priority order):**

| Signal | Reliability | Notes |
|--------|------------|-------|
| Window class contains `ShortsActivity` or `shorts` | High | YouTube's internal activity name |
| Selected tab text == "Shorts" | High | Bottom nav tab state |
| Vertical `ViewPager` / `RecyclerView` with video content | Medium | Shorts uses vertical swipe |
| Visible text containing "Shorts" in specific view hierarchy position | Medium | Can false-positive on Shorts shelf in Home |

Use at least 2 signals before triggering. Log all detections for the first week before enabling auto-block.

**Done when:** service logs "SHORTS_DETECTED" when you open YouTube Shorts on a real device.

---

### 1.9 Overlay service

**File:** `android/app/src/main/kotlin/.../focusguard/FocusGuardOverlayService.kt`
**File:** `android/app/src/main/res/layout/focus_guard_overlay.xml`

Overlay UI:
- Full-screen semi-transparent blocker
- Islamic reminder text (hardcoded for MVP: "Remember Allah and return to what benefits you")
- "Go Back" button (primary, prominent)
- "Allow 5 min" / "Allow 10 min" buttons (secondary, smaller)
- Prevent duplicate overlays (check `isOverlayShowing` flag)

Window params:
```kotlin
val params = WindowManager.LayoutParams(
    WindowManager.LayoutParams.MATCH_PARENT,
    WindowManager.LayoutParams.MATCH_PARENT,
    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, // Android 8+
    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
    PixelFormat.TRANSLUCENT
)
```

Button actions:
- **Go Back:** dismiss overlay, `performGlobalAction(GLOBAL_ACTION_BACK)` from accessibility service
- **Allow X min:** save `System.currentTimeMillis() + X * 60000` to SharedPreferences as temp-allow expiry, dismiss overlay

**Done when:** overlay appears over YouTube Shorts, buttons work, temp-allow prevents re-trigger for the set duration.

---

### 1.10 End-to-end integration test

On a real Android device:
- [ ] Enable Accessibility + Overlay permissions from Focus Guard screen
- [ ] Toggle YouTube blocking ON
- [ ] Open YouTube → navigate to Shorts → overlay appears
- [ ] Tap "Go Back" → returns to YouTube home (not Shorts)
- [ ] Navigate to Shorts again → overlay appears again
- [ ] Tap "Allow 10 min" → overlay dismisses, Shorts accessible for 10 min
- [ ] After 10 min → Shorts blocked again
- [ ] Return to Jamaat Time → toggle OFF → munajat dialog appears
- [ ] Wait 15 seconds → disable button becomes active
- [ ] Cancel → guard stays ON
- [ ] Confirm → guard turns OFF, Shorts no longer blocked

**Ship gate:** Do NOT proceed to Milestone 2 until all checks pass.

---

## Milestone 2 — Stability & polish

### 2.1 Separate detector engine

Refactor the inline detection from 1.8 into:

**File:** `android/app/src/main/kotlin/.../focusguard/FocusGuardDetector.kt`

```kotlin
interface AppSurfaceDetector {
    val packageName: String
    fun detect(event: AccessibilityEvent, rootNode: AccessibilityNodeInfo?): DetectionResult?
}

data class DetectionResult(
    val surface: String,    // "shorts", "reels", "feed"
    val confidence: Float,  // 0.0 - 1.0
    val signals: List<String>
)

class YouTubeShortsDetector : AppSurfaceDetector { ... }
// Stub: class InstagramReelsDetector : AppSurfaceDetector { ... }
```

**Done when:** detection logic is testable independently of AccessibilityService lifecycle.

---

### 2.2 Block history (local)

Store last 100 events in SharedPreferences as JSON array:
```json
[{"app": "youtube", "surface": "shorts", "action": "blocked", "ts": 1713100800000}, ...]
```

Show in Focus Guard screen: "Blocked 12 times today" + simple list.

---

### 2.3 OEM-specific reliability

Test and document behavior on:
- Samsung (One UI) — aggressive battery optimization
- Xiaomi (MIUI) — autostart restrictions
- Oppo/Realme (ColorOS) — similar to Xiaomi
- Stock Android / Pixel — generally fine

Add a "Troubleshooting" section in the setup screen if the service keeps getting killed, with a button to open device-specific battery settings.

---

### 2.4 Google Play compliance

**AccessibilityService policy requirements:**
1. The `android:description` string MUST clearly explain the app monitors screen content to block short-video feeds for digital wellbeing
2. Privacy policy must state: what data is accessed (package names, screen content), that NO data leaves the device, no personal data is collected
3. The Accessibility Declaration Form on Google Play Console must be filled accurately
4. Consider adding a toggle to fully disable the accessibility service from within the app (not just the blocking feature)

**Alternative approach if Play Store rejects:**
- `UsageStatsManager` can detect which app is in foreground but CANNOT detect Shorts vs regular YouTube. It's a weaker fallback.
- Distribution via APK sideload / alternative stores if needed

---

## Milestone 3 — Prayer-aware + expansion

### 3.1 Prayer-aware blocking

Integrate with existing `PrayerTimeEngine` (or `PrayerCalculationService`):

```dart
// In focus_guard_service.dart
void syncPrayerTimesToNative() {
  final engine = PrayerTimeEngine.instance;
  final times = engine.createPrayerTimesMap(prayerTimes);
  // Send next 6 prayer timestamps to native via channel
  _channel.invokeMethod('updatePrayerTimes', {
    'fajr': times['Fajr']?.millisecondsSinceEpoch,
    'dhuhr': times['Dhuhr']?.millisecondsSinceEpoch,
    // ...
  });
}
```

Native side: "Pause until next prayer" reads next prayer timestamp and saves as temp-allow expiry.

Optional: "Auto-block X minutes before prayer" reads upcoming prayer timestamp and activates blocking automatically.

---

### 3.2 Add Instagram Reels detector

**File:** `InstagramReelsDetector.kt` implementing `AppSurfaceDetector`

Package: `com.instagram.android`

Detection signals:
- Reels tab selected in bottom navigation
- Vertical ViewPager in Reels viewer
- "Reels" text in specific hierarchy position

Add ONE app at a time. Stabilize each before adding the next.

---

### 3.3 Add Facebook Reels + TikTok

Same pattern as 3.2. Facebook package: `com.facebook.katana`. TikTok: `com.zhiliaoapp.musically`.

---

### 3.4 Enhanced munajat on overlay

Instead of static text on the overlay, show a random munajat (Arabic + meaning) from the 47 entries. This requires passing munajat data to the native overlay. Options:
- Sync a small set of munajat strings to native SharedPreferences
- Or render overlay via Flutter (more complex but richer UI)

Recommended: sync 10 random munajat at settings-save time as JSON to native prefs. Overlay picks one randomly.

---

## Android version compatibility

| Android version | Overlay type | Notes |
|----------------|-------------|-------|
| 8.0+ (API 26) | `TYPE_APPLICATION_OVERLAY` | Required. Older types deprecated. |
| 10+ (API 29) | Same | `canDrawOverlays()` check required |
| 12+ (API 31) | Same | Accessibility service restrictions tighter |
| 13+ (API 33) | Same | Per-app notification permission (already in manifest) |

Minimum supported: Android 8.0 (API 26). This covers 95%+ of active devices.

---

## Sequence diagram (corrected)

```
User opens YouTube Shorts
  → Android fires AccessibilityEvent
  → FocusGuardAccessibilityService.onAccessibilityEvent()
    → Check: enabled? youtube blocked? not temp-allowed? debounce clear?
    → YouTubeShortsDetector.detect(event, rootNode)
    → Result: surface=shorts, confidence=0.92
    → Action: performGlobalAction(BACK) + show overlay
  → FocusGuardOverlayService shows blocker
    → User taps "Allow 10 min"
    → Save expiry to SharedPreferences
    → Dismiss overlay
    → Next Shorts access within 10 min: debounce check passes, no block
```

```
User toggles Focus Guard OFF in app
  → FocusGuardScreen intercepts toggle
  → FocusGuardService.getRandomMunajat() → random from 47 entries
  → MunajatDisableDialog opens
    → Shows Arabic + pronunciation + meaning
    → 15-second countdown timer
    → "Disable" button greyed out
    → After 15s: button turns red, enabled
    → User taps "Disable" → saveSettings(enabled: false) → sync to native
    → OR user taps Cancel / back → guard stays ON
```

---

## MVP task checklist (revised)

### A. Flutter side
- [ ] Create `FocusGuardSettings` model
- [ ] Create `FocusGuardService` with SharedPreferences + MethodChannel
- [ ] Create `MunajatDisableDialog` widget (15s countdown + random munajat)
- [ ] Create `FocusGuardScreen` (permissions + master toggle + app toggles)
- [ ] Add navigation entry point to existing app
- [ ] Wire munajat dialog to master toggle OFF action

### B. Android native side
- [ ] Add `SYSTEM_ALERT_WINDOW` permission to manifest
- [ ] Register AccessibilityService in manifest
- [ ] Create accessibility config XML
- [ ] Add `focus_guard_description` string resource
- [ ] Create `FocusGuardChannel.kt` (permission checks + settings sync)
- [ ] Register channel in `MainActivity.kt`
- [ ] Create `FocusGuardAccessibilityService.kt` (event listener + YouTube detection + debounce)
- [ ] Create `FocusGuardOverlayService.kt` + layout XML

### C. Integration
- [ ] Flutter toggle → native settings sync verified
- [ ] Permission status shown accurately in UI
- [ ] YouTube Shorts detection works on real device (log-only first)
- [ ] Overlay appears and buttons work
- [ ] Temp-allow expiry works
- [ ] Munajat dialog blocks immediate disable for 15 seconds
- [ ] Random munajat selection from 47 entries works

### D. QA (real device)
- [ ] YouTube Shorts blocked reliably
- [ ] Regular YouTube videos NOT blocked (false positive check)
- [ ] YouTube home/search/subscriptions NOT blocked
- [ ] Overlay doesn't flash/repeat (debounce works)
- [ ] Temp allow works and expires correctly
- [ ] Service survives app backgrounding
- [ ] Service survives screen off/on
- [ ] Munajat dialog countdown accurate (not skippable)
- [ ] Cancel on munajat dialog preserves ON state
- [ ] Test on at least 2 different Android versions

---

## Week-by-week schedule (revised)

### Week 1
- Flutter model + service + screen + munajat dialog
- Manifest + accessibility config + channel bridge
- End state: UI complete with mock native responses

### Week 2
- AccessibilityService + YouTube detection (log-only)
- Overlay service + layout
- End state: detection logs on real device, overlay shows

### Week 3
- Connect everything end-to-end
- Debounce tuning + false positive reduction
- Temp-allow flow
- QA on real devices

### Week 4
- Bug fixes from QA
- OEM-specific testing (Samsung, Xiaomi if available)
- Google Play compliance prep (description string, privacy policy)
- Ship YouTube-only MVP

### Post-MVP (only after stable YouTube blocker)
- Instagram Reels detector
- Prayer-aware blocking
- Block history UI
- Facebook Reels + TikTok
- Munajat on overlay (native side)

---

## Critical constraints

- **Do NOT build all detectors at once.** YouTube first, stabilize, then one app at a time.
- **Do NOT skip the munajat dialog.** It is a core spiritual feature, not optional.
- **Do NOT use DataStore or Room for MVP storage.** SharedPreferences is sufficient and already a dependency.
- **Do NOT render overlay via Flutter engine.** Native overlay is faster, more reliable, and works when the Flutter engine isn't running.
- **Do NOT hardcode coordinates or prayer times in native code.** Always receive them from Flutter's existing prayer infrastructure via channel.
- **Do NOT remove the 15-second munajat delay.** The spiritual reflection moment is non-negotiable by design.
