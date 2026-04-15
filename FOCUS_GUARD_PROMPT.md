# Task: Implement Focus Guard — Milestone 1 (YouTube Shorts Blocker MVP)

Read `FOCUS_GUARD_PLAN_v2.md` for full context. This prompt covers Milestone 1 only.

## Existing codebase context

- **Flutter app** at project root. Flat architecture: `lib/models/`, `lib/services/`, `lib/screens/`, `lib/widgets/`, `lib/data/`.
- **Android native** at `android/app/src/main/kotlin/com/example/jamaat_time/`. Only `MainActivity.kt` exists with one MethodChannel (`jamaat_time/screen_awake`).
- **Manifest** at `android/app/src/main/AndroidManifest.xml` — already has location, notification, boot, and home widget permissions/services.
- **Munajat data** at `lib/data/monajat_data.dart` — exports `allMonajatList` (47 `MonajatModel` entries). Model at `lib/models/monajat_model.dart` has fields: `id`, `title`, `arabic`, `pronunciation`, `meaning`, `context`.
- **MonajatDetailScreen** at `lib/screens/ebadat/topics/monajat_detail_screen.dart` — reference for Arabic text styling (uses `google_fonts` Amiri, teal theme).
- **pubspec.yaml** already has: `shared_preferences`, `google_fonts`, `intl`.
- **App package:** `com.example.jamaat_time`

## What to build (8 deliverables in order)

### 1. `lib/models/focus_guard_settings.dart`
Minimal immutable model:
```dart
class FocusGuardSettings {
  final bool enabled;
  final Map<String, bool> blockedApps; // {'youtube': true}
  final int tempAllowMinutes;          // default 10
  // const constructor, toJson, fromJson (for SharedPreferences JSON string), copyWith
}
```

### 2. `lib/services/focus_guard_service.dart`
Service singleton. Responsibilities:
- Load/save `FocusGuardSettings` via SharedPreferences (key: `focus_guard_settings`, store as JSON string)
- MethodChannel `jamaat_time/focus_guard` for native bridge
- Methods: `loadSettings()`, `saveSettings(settings)`, `syncSettingsToNative(settings)`, `getPermissionStatus()` → `{'accessibility': bool, 'overlay': bool}`, `openAccessibilitySettings()`, `openOverlaySettings()`, `getRandomMunajat()` → random entry from `allMonajatList`
- On every `saveSettings`, also call `syncSettingsToNative`

### 3. `lib/widgets/focus_guard/munajat_disable_dialog.dart`
Modal bottom sheet widget. Takes `MonajatModel monajat` and `VoidCallback onConfirmDisable`.

Behavior:
- Shows random munajat: Arabic text (Amiri font, 26pt, RTL, centered, teal container — match MonajatDetailScreen style), pronunciation (italic), meaning (regular)
- 15-second countdown timer displayed as "Please reflect for 15 seconds... (12s)"
- "Disable Focus Guard" button is GREYED OUT and disabled during countdown
- After 15s: button turns red/orange, enabled. Tapping calls `onConfirmDisable` and pops
- "Cancel" button always available — pops without disabling
- Timer cancels in dispose

### 4. `lib/screens/focus_guard_screen.dart`
Single screen. Sections from top to bottom:
- **Permission cards:** two cards showing Accessibility and Overlay permission status (green check / red X). Each has a "Setup" button calling `openAccessibilitySettings()` / `openOverlaySettings()`. Refresh status on screen resume (`WidgetsBindingObserver` → `didChangeAppLifecycleState`)
- **Master toggle:** "Focus Guard" switch. ON→OFF triggers `MunajatDisableDialog`. OFF→ON saves directly.
- **App toggles:** YouTube (functional toggle), Instagram/Facebook/TikTok (disabled, show "Coming soon" chip)
- **Quick allow selector:** segmented button or dropdown for 5/10/15 min default
- Style: match existing app's green brand theme (`AppConstants.brandGreen`)

Add navigation to this screen from the appropriate place in the existing app (check home_screen or profile_screen for settings/nav patterns).

### 5. `android/app/src/main/AndroidManifest.xml` — edits
Add to `<manifest>` (before `<application>`):
```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
```

Add inside `<application>` (after existing services):
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

Add string resource `android/app/src/main/res/values/strings.xml` (create if missing):
```xml
<resources>
    <string name="focus_guard_description">JamaatTime Focus Guard monitors screen content to detect short-video feeds (YouTube Shorts, Reels) and helps you stay focused by blocking distracting content. No data leaves your device.</string>
</resources>
```

### 6. `android/app/src/main/res/xml/focus_guard_accessibility_config.xml`
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

### 7. `android/app/src/main/kotlin/com/example/jamaat_time/focusguard/FocusGuardChannel.kt`
Kotlin class registered in MainActivity. Channel name: `jamaat_time/focus_guard`.

Methods:
- `isAccessibilityEnabled` → check if `FocusGuardAccessibilityService` is in enabled accessibility services list
- `isOverlayEnabled` → `Settings.canDrawOverlays(context)`
- `openAccessibilitySettings` → `Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)`
- `openOverlaySettings` → `Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))`
- `updateSettings` → receive JSON string arg, save to SharedPreferences key `focus_guard_native_settings`

**Wire in MainActivity.kt:** add inside existing `configureFlutterEngine`, AFTER the existing screen_awake channel:
```kotlin
FocusGuardChannel(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
```

### 8. `android/app/src/main/kotlin/com/example/jamaat_time/focusguard/FocusGuardAccessibilityService.kt`
Core service. In a single file for MVP (no separate detector class yet).

```kotlin
class FocusGuardAccessibilityService : AccessibilityService() {
    private var lastActionTime = 0L
    private val DEBOUNCE_MS = 2000L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 1. Null check event
        // 2. Read settings from SharedPreferences ("focus_guard_native_settings")
        //    If not enabled or youtube not blocked → return
        // 3. Check package == "com.google.android.youtube"
        // 4. Check temp-allow: if prefs "focus_guard_temp_allow_expiry" > currentTimeMillis → return
        // 5. Debounce: if currentTimeMillis - lastActionTime < DEBOUNCE_MS → return
        // 6. Detect Shorts:
        //    Signal A: event.className contains "Shorts" (case-insensitive)
        //    Signal B: rootInActiveWindow node tree search for text "Shorts" in selected tab state
        //    Signal C: vertical ViewPager / RecyclerView pattern
        //    Require at least 1 strong signal (A) or 2 weak signals (B+C)
        // 7. If detected:
        //    lastActionTime = currentTimeMillis
        //    performGlobalAction(GLOBAL_ACTION_BACK)
        //    showOverlay()
    }

    private fun showOverlay() {
        // Check canDrawOverlays
        // Create WindowManager.LayoutParams TYPE_APPLICATION_OVERLAY
        // Inflate layout or build programmatically:
        //   - Semi-transparent dark background (full screen)
        //   - Title: "Focus Guard Active"
        //   - Subtitle: "Short videos are blocked to help you stay focused"
        //   - "Go Back" button → dismiss overlay
        //   - "Allow X min" button → save expiry to prefs, dismiss overlay
        // Prevent duplicate overlay (track isShowing flag)
    }

    private fun dismissOverlay() { ... }
    override fun onInterrupt() {}
    override fun onDestroy() { dismissOverlay(); super.onDestroy() }
}
```

For the overlay: build views programmatically (no XML layout needed for MVP) OR create `android/app/src/main/res/layout/focus_guard_overlay.xml`. Either approach is fine — choose whichever is cleaner.

## Critical constraints

- **DO NOT** create `lib/features/` directory. Use existing flat structure.
- **DO NOT** build Instagram/Facebook/TikTok detectors. Stubs only in the Flutter UI.
- **DO NOT** touch existing prayer time services, home screen logic, or notification services.
- **DO NOT** skip the munajat disable dialog. It must show a random munajat from `allMonajatList` with a 15-second enforced countdown.
- **DO NOT** use DataStore or Room. Use SharedPreferences only.
- **DO NOT** create separate DetectorEngine, RuleEngine, SessionManager, HistoryStore classes. Keep it simple for MVP — all in `FocusGuardAccessibilityService.kt`.
- **DO** run `flutter analyze` after all Flutter changes.
- **DO** verify the manifest XML is valid (no duplicate tags, proper nesting).
- **DO** match the existing app's visual style (green brand theme from `AppConstants`).
