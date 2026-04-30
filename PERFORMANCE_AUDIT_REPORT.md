# Jamaat Time Performance Audit Report

## Executive Summary

Jamaat Time is close to release from a build-output perspective, but it is not performance-release-clean yet. The Android APK and AAB release builds complete successfully, but the app has blocking static-analysis errors, startup work before first frame, background/widget scheduling that is heavier than necessary, and several always-running timers/animations on the Home tab.

The highest-risk areas before release are Android widget scheduling and exact-alarm policy exposure, first-frame startup work in `lib\main.dart`, and the failing analyzer errors in `test_ebadat_service.dart`.

Static checks run:

- `flutter analyze`: failed with 250 issues; 3 are analyzer errors in `test_ebadat_service.dart`.
- `flutter pub deps --style=compact`: completed; Flutter SDK `3.35.6`, Dart SDK `3.9.2`, app version `2.0.22+10`.
- `flutter pub outdated`: completed; 53 locked dependencies are upgradable, and 41 dependencies are constrained below a resolvable newer version.
- `flutter build apk --release`: passed; output `build\app\outputs\flutter-apk\app-release.apk`, size 68.5 MB.
- `flutter build appbundle --release`: passed; output `build\app\outputs\bundle\release\app-release.aab`, size 54.2 MB.

## Overall Release Readiness

**Needs Performance Fixes**

The release build itself works, but the app should not be treated as release-ready until the analyzer errors, exact-alarm/widget scheduling risks, startup blocking work, and Home tab timer lifecycle are addressed. These are focused fixes and do not require a redesign.

## Priority Findings

## P0 — Must Fix Before Release

### 1. Widget background refresh and exact-alarm usage are too aggressive for release

**Problem**
The Android widget has three overlapping refresh mechanisms: native exact/boundary alarms, a 15-minute WorkManager maintenance job, and `android:updatePeriodMillis="1800000"`. The app also declares sensitive exact-alarm and battery-optimization permissions.

**Evidence from code**

- `android\app\src\main\java\com\sadat\jamaattime\PrayerWidgetProvider.java:193` in `scheduleAlarmClock()` uses `AlarmManager.setAlarmClock()`.
- `android\app\src\main\java\com\sadat\jamaattime\PrayerWidgetProvider.java:205` falls back to `setExactAndAllowWhileIdle()`.
- `android\app\src\main\java\com\sadat\jamaattime\PrayerWidgetProvider.java:214` in `scheduleAllAlarms()` schedules prayer, Jamaat, Jamaat-over, and midnight alarms.
- `android\app\src\main\kotlin\com\sadat\jamaattime\MainActivity.kt:19` enqueues `widget_maintenance` every 15 minutes on every engine configuration.
- `android\app\src\main\java\com\sadat\jamaattime\PrayerWidgetProvider.java:353` also enqueues `widget_maintenance` in `PrayerWidgetProvider.onEnabled()`.
- `android\app\src\main\kotlin\com\sadat\jamaattime\WidgetMaintenanceWorker.kt:13` sends a HomeWidget background broadcast each run.
- `android\app\src\main\res\xml\prayer_widget_info.xml:9` sets `android:updatePeriodMillis="1800000"`.
- `android\app\src\main\AndroidManifest.xml:9`, `:10`, and `:11` declare `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, and `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.

**File path**
`android\app\src\main\java\com\sadat\jamaattime\PrayerWidgetProvider.java`
`android\app\src\main\kotlin\com\sadat\jamaattime\MainActivity.kt`
`android\app\src\main\kotlin\com\sadat\jamaattime\WidgetMaintenanceWorker.kt`
`android\app\src\main\AndroidManifest.xml`

**Why it matters**
This can increase wakeups, battery usage, and Play Store review risk. `USE_EXACT_ALARM` and battery optimization exemption need strong justification and should not be paired with unnecessary periodic background refreshes.

**Minimal fix direction**
Keep boundary-based widget refresh only for next prayer, next Jamaat, Jamaat-over, and midnight. Do not enqueue 15-minute maintenance from `MainActivity.configureFlutterEngine()`. Ensure `widget_maintenance` exists only while widgets are enabled and is cancelled in `PrayerWidgetProvider.onDisabled()`. Re-check whether both exact-alarm permissions are required.

**Risk of not fixing**
Battery complaints, stale-widget recovery causing excessive background work, and possible Play policy rejection or review delay.

### 2. App startup blocks first frame with Firebase, notifications, fonts, and FCM work

**Problem**
`main()` awaits several heavy operations before `runApp()`: timezone initialization, Firebase initialization, notification initialization/channel setup, locale bootstrap, Google font preloading, and FCM setup.

**Evidence from code**

- `lib\main.dart:30` calls `tzdata.initializeTimeZones()`.
- `lib\main.dart:35` awaits `Firebase.initializeApp()`.
- `lib\main.dart:58` awaits `NotificationService.initialize(null)`.
- `lib\main.dart:69` awaits `AppLocaleController.bootstrap()`.
- `lib\main.dart:70` awaits `_preloadActiveLocaleFonts()`.
- `lib\main.dart:94` awaits `GoogleFonts.pendingFonts()`.
- `lib\main.dart:75` awaits `FcmService().init(...)`.
- `lib\services\notifications\fcm_service.dart:74` requests FCM permission, `:80` subscribes to `all_users`, and `:86` fetches the FCM token during init.

**File path**
`lib\main.dart`
`lib\services\notifications\fcm_service.dart`
`lib\services\notification_service.dart`

**Why it matters**
Cold start can be delayed by network, disk, Google font, Firebase, and notification permission work. The user sees no Flutter UI until all awaited startup tasks complete.

**Minimal fix direction**
Keep `WidgetsFlutterBinding.ensureInitialized()`, timezone setup if required for notification correctness, Firebase core if absolutely required by first route, and locale bootstrap before first frame. Defer notification channel creation, FCM topic/token writes, bookmark auth listener initialization, and font preloading to a post-frame task.

**Risk of not fixing**
Slow cold start, delayed first frame, and inconsistent startup time on weak devices or poor networks.

### 3. Analyzer fails before release

**Problem**
`flutter analyze` fails with real errors, not only informational lints.

**Evidence from code**

- `test_ebadat_service.dart:24:40` missing required named parameter `locale`.
- `test_ebadat_service.dart:27:39` missing required named parameter `locale`.
- `test_ebadat_service.dart:31:39` missing required named parameter `locale`.
- `lib\main.dart:65` uses deprecated `HomeWidget.registerBackgroundCallback`.

**File path**
`test_ebadat_service.dart`
`lib\main.dart`

**Why it matters**
Release should not proceed with analyzer errors. The deprecated HomeWidget callback is especially relevant because this audit found widget refresh as a high-risk release area.

**Minimal fix direction**
Update or remove the root `test_ebadat_service.dart` script from analyzer scope. Replace deprecated `HomeWidget.registerBackgroundCallback` with the supported callback API if it is still required.

**Risk of not fixing**
CI/release gate failure and increased risk that widget background behavior breaks in a future `home_widget` update.

## P1 — Strongly Recommended Before Release

### 1. Home tab timers keep running while hidden by bottom navigation

**Problem**
`MainScaffold` uses an `IndexedStack`, so inactive tabs stay mounted. Home widgets continue their timers even when the user is on Ebadat, Calendar, or Profile.

**Evidence from code**

- `lib\main.dart:175` uses `IndexedStack(index: _selectedIndex, children: _screens)`.
- `lib\widgets\prayer_countdown_widget.dart:66` starts a one-second `Timer.periodic`.
- `lib\widgets\sahri_iftar_widget.dart:247` starts another one-second `Timer.periodic`.
- `lib\widgets\live_clock_widget.dart:47` starts a 60-second `Timer.periodic`.
- `lib\widgets\forbidden_times_widget.dart:157` starts a one-minute `Timer.periodic`.
- `lib\screens\home_screen.dart:685` starts a one-minute HomeScreen timer.

**File path**
`lib\main.dart`
`lib\screens\home_screen.dart`
`lib\widgets\prayer_countdown_widget.dart`
`lib\widgets\sahri_iftar_widget.dart`
`lib\widgets\live_clock_widget.dart`
`lib\widgets\forbidden_times_widget.dart`

**Minimal fix direction**
Pass Home tab visibility from `MainScaffold` to `HomeScreen` and pause countdown/live timers when the Home tab is not active or app lifecycle is paused.

### 2. `ForbiddenTimesWidget` runs animation even when no forbidden time is active

**Problem**
The pulse `AnimationController` starts repeating in `initState()` for every mounted `ForbiddenTimesWidget`, even outside active forbidden windows.

**Evidence from code**

- `lib\widgets\forbidden_times_widget.dart:148` creates `_pulseController`.
- `lib\widgets\forbidden_times_widget.dart:151` immediately calls `repeat(reverse: true)`.
- `lib\widgets\forbidden_times_widget.dart:323` only uses `AnimatedBuilder` when `isActive && !reduceMotion`.

**File path**
`lib\widgets\forbidden_times_widget.dart`

**Minimal fix direction**
Start `_pulseController.repeat()` only when an active forbidden window exists. Stop it when no window is active or animations are disabled.

### 3. Countdown recalculates tomorrow Fajr every second after Isha

**Problem**
After all prayers have passed, countdown progress and time-to-next-prayer calculation construct tomorrow's `PrayerTimes` repeatedly during the one-second timer.

**Evidence from code**

- `lib\widgets\prayer_countdown_widget.dart:67` recalculates every second.
- `lib\widgets\prayer_countdown_widget.dart:139` calls `PrayerTimeEngine.getTimeToNextPrayerSafe(...)`.
- `lib\widgets\prayer_countdown_widget.dart:214` creates `PrayerTimes(...)` for tomorrow Fajr inside `_calculateProgress()`.
- `lib\services\prayer_time_engine.dart` also computes tomorrow Fajr in `getTimeToNextPrayerSafe()`.

**File path**
`lib\widgets\prayer_countdown_widget.dart`
`lib\services\prayer_time_engine.dart`

**Minimal fix direction**
Cache tomorrow Fajr in `PrayerCountdownWidget` for the current date, coordinates, and calculation parameters. Invalidate only when date/location/params change.

### 4. Location fetch uses high accuracy without timeout

**Problem**
Manual location fetch requests high accuracy and has no timeout or low-power fallback.

**Evidence from code**

- `lib\services\location_service.dart:32` calls `Geolocator.getCurrentPosition(...)`.
- `lib\services\location_service.dart:33` uses `LocationAccuracy.high`.
- `lib\screens\home_screen.dart:1033` calls this through `HomeScreen._fetchUserLocation()`.

**File path**
`lib\services\location_service.dart`
`lib\screens\home_screen.dart`

**Minimal fix direction**
Use a timeout and prefer balanced/medium accuracy for prayer-time location unless the user explicitly requests precise GPS. Keep the existing cached fallback in `HomeScreen._fetchUserLocation()`.

### 5. Notification rescheduling cancels all notifications too often

**Problem**
`NotificationService.scheduleAllNotifications()` cancels all pending notifications before scheduling. `HomeScreen._updatePrayerTimes()` can reset `_notificationsScheduled` and call scheduling when `jamaatTimes != null`.

**Evidence from code**

- `lib\services\notification_service.dart:879` defines `scheduleAllNotifications(...)`.
- `lib\services\notification_service.dart:884` calls `cancelAllNotifications()`.
- `lib\screens\home_screen.dart:938` resets `_notificationsScheduled = false`.
- `lib\screens\home_screen.dart:940` calls `_scheduleNotificationsIfNeeded()`.

**File path**
`lib\services\notification_service.dart`
`lib\screens\home_screen.dart`

**Minimal fix direction**
Keep the existing notification IDs, but only reschedule when date, location config, Jamaat times, or notification settings actually changed.

### 6. Notice bell performs async read-state check inside a nested builder

**Problem**
`HomeScreen._buildNoticeAction()` uses a `StreamBuilder` for latest notice and a nested `FutureBuilder` for unread status. This can re-run SharedPreferences read-state checks when the parent rebuilds.

**Evidence from code**

- `lib\screens\home_screen.dart:161` creates `StreamBuilder<NoticeModel?>`.
- `lib\screens\home_screen.dart:165` creates `FutureBuilder<bool>`.
- `lib\screens\home_screen.dart:166` calls `_noticeReadState.hasUnreadLatest(latest)`.
- `lib\features\notice_board\data\notice_read_state_service.dart:25` runs read-state logic.

**File path**
`lib\screens\home_screen.dart`
`lib\features\notice_board\data\notice_read_state_service.dart`

**Minimal fix direction**
Cache unread state per latest notice ID/published date, and refresh only when the latest notice changes or when `_openNoticeBoard()` marks items seen.

## P2 — Polish / Optimization

### 1. Release build has shrinking disabled

`android\app\build.gradle.kts:62` sets `isMinifyEnabled = false`, and `android\app\build.gradle.kts:63` sets `isShrinkResources = false`. The APK is 68.5 MB and AAB is 54.2 MB. Test R8/resource shrinking with existing `android\app\proguard-rules.pro` before final release.

### 2. Home rendering uses several shadows, gradients, and `IntrinsicHeight`

Evidence:

- `lib\screens\home_screen.dart:248` and `:299` use header gradients.
- `lib\screens\home_screen.dart:255`, `:309`, `:1775`, and `:1852` use shadows.
- `lib\screens\home_screen.dart:1492` uses `IntrinsicHeight` in every prayer row.
- `lib\core\app_theme_tokens.dart:44`, `:48`, and `:52` define shared shadows.

Minimal fix direction: remove `IntrinsicHeight` from fixed-height prayer rows first. Then reduce shadow blur where visual difference is small.

### 3. `PrayerCountdownWidget` has minor dead code/lint issues

Evidence:

- `lib\widgets\prayer_countdown_widget.dart:3` unnecessary `dart:ui` import.
- `lib\widgets\prayer_countdown_widget.dart:330` optional `strokeWidth` parameter is never given.

Minimal fix direction: clean these small analyzer warnings when touching countdown lifecycle.

### 4. Debug and diagnostic logs are noisy in release paths

Evidence:

- `lib\features\notice_board\data\notice_telemetry.dart:7` uses `debugPrint(...)`.
- `lib\services\widget_service.dart:37` and `:137` print widget background errors.
- `android\app\src\main\java\com\sadat\jamaattime\PrayerWidgetProvider.java` uses repeated `Log.d(...)` at `:73`, `:200`, `:273`, `:328`, `:340`, `:355`, and `:374`.
- `android\app\src\main\kotlin\com\sadat\jamaattime\focusguard\FocusGuardAccessibilityService.kt` uses repeated `Log.d(...)` at `:43`, `:67`, `:85`, `:91`, and `:155`.

Minimal fix direction: gate verbose logs behind debug/build config and keep only warning/error logs needed for production diagnostics.

## P3 — Optional Future Improvements

- Add startup profiling using `flutter run --profile --trace-startup` and keep a baseline before each release.
- Add widget alarm/job verification to release QA using `adb shell dumpsys alarm` and `adb shell dumpsys jobscheduler`.
- Add a small performance test around Home tab inactive timer pausing.
- Consider moving large non-Android-only packages such as `msix`, `file_picker`, and admin-only dependencies out of Android release paths if future size audits show they affect APK/AAB size.
- Add cached `DateFormat` instances for hot display paths if profiling shows allocation churn.

## Top 10 Improvement List Before Release

### 1. Limit widget background scheduling

Priority: P0
Affected file: `android\app\src\main\java\com\sadat\jamaattime\PrayerWidgetProvider.java`, `android\app\src\main\kotlin\com\sadat\jamaattime\MainActivity.kt`
Why important: Reduces wakeups, battery risk, and Play policy exposure.
Suggested fix: Remove the unconditional 15-minute WorkManager enqueue from `MainActivity.configureFlutterEngine()` and keep widget refresh tied to prayer/Jamaat/midnight boundaries.

### 2. Re-check exact alarm and battery optimization permissions

Priority: P0
Affected file: `android\app\src\main\AndroidManifest.xml`
Why important: `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, and `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` are sensitive permissions.
Suggested fix: Keep only permissions that are strictly required and document the Play Console declaration reason.

### 3. Move heavy startup work after first frame

Priority: P0
Affected file: `lib\main.dart`, `lib\services\notifications\fcm_service.dart`
Why important: Cold start should not wait for FCM token writes, topic subscription, notification channel setup, or font network/cache work.
Suggested fix: Run non-critical work after `runApp()` with a post-frame or unawaited bootstrap path.

### 4. Fix analyzer errors

Priority: P0
Affected file: `test_ebadat_service.dart`, `lib\main.dart`
Why important: `flutter analyze` currently fails.
Suggested fix: Add required `locale` arguments or exclude/remove the root test script; replace deprecated `HomeWidget.registerBackgroundCallback`.

### 5. Pause Home timers when Home tab is inactive

Priority: P1
Affected file: `lib\main.dart`, `lib\screens\home_screen.dart`, `lib\widgets\prayer_countdown_widget.dart`, `lib\widgets\sahri_iftar_widget.dart`
Why important: `IndexedStack` keeps inactive Home timers alive.
Suggested fix: Pass active-tab state and stop/restart timers based on tab and app lifecycle.

### 6. Stop forbidden-times animation unless active

Priority: P1
Affected file: `lib\widgets\forbidden_times_widget.dart`
Why important: Avoids unnecessary animation ticks most of the day.
Suggested fix: Only call `_pulseController.repeat()` while at least one `ForbiddenWindow.isActive(now)` is true.

### 7. Cache tomorrow Fajr for countdown

Priority: P1
Affected file: `lib\widgets\prayer_countdown_widget.dart`
Why important: Avoids repeated `PrayerTimes` construction every second after Isha.
Suggested fix: Cache tomorrow Fajr until date, coordinates, or calculation parameters change.

### 8. Add timeout and lower-power accuracy for location

Priority: P1
Affected file: `lib\services\location_service.dart`
Why important: Prevents long GPS waits and reduces battery usage.
Suggested fix: Use balanced accuracy plus timeout, falling back to saved `last_latitude` and `last_longitude`.

### 9. Avoid full cancel/reschedule notification cycles when inputs did not change

Priority: P1
Affected file: `lib\screens\home_screen.dart`, `lib\services\notification_service.dart`
Why important: Reduces notification scheduling overhead and exact alarm churn.
Suggested fix: Track the last scheduling input key: date, city/location, madhab, Jamaat map hash, and sound settings.

### 10. Enable and test shrinking

Priority: P2
Affected file: `android\app\build.gradle.kts`, `android\app\proguard-rules.pro`
Why important: Current APK is 68.5 MB.
Suggested fix: Test `isMinifyEnabled=true` and `isShrinkResources=true` in release builds.

## Home Screen Specific Findings

- `HomeScreen` uses `Timer.periodic(const Duration(minutes: 1))` in `lib\screens\home_screen.dart:685`; it is disposed at `:1221`, but it stays alive while Home is hidden because of `IndexedStack`.
- `PrayerCountdownWidget` owns a one-second timer at `lib\widgets\prayer_countdown_widget.dart:66`; it correctly cancels at `:239`, but it does not pause when the tab is inactive.
- `SahriIftarWidget` owns a one-second timer at `lib\widgets\sahri_iftar_widget.dart:247`; it cancels at `:291`, but it also stays active under `IndexedStack`.
- `ForbiddenTimesWidget` owns a one-minute timer at `lib\widgets\forbidden_times_widget.dart:157` and a repeating animation at `:151`; the animation is the bigger issue because it runs even when no active window is visible.
- Prayer rows are precomputed in `HomeScreen._computePrayerTableData()` at `lib\screens\home_screen.dart:1261`, which is good. However, each row uses `IntrinsicHeight` in `_buildPrayerCard()` at `lib\screens\home_screen.dart:1492`; this is unnecessary for a fixed row layout.
- Heavy rendering cost is moderate but visible: header shadows at `lib\screens\home_screen.dart:255` and `:309`, section shadows at `:1775` and `:1852`, and row shadows from `AppShadows.subtle`.
- `HomeScreen._buildNoticeAction()` at `lib\screens\home_screen.dart:156` combines `StreamBuilder` and `FutureBuilder`; cache unread state to avoid repeated async work during rebuilds.

## Android Widget Specific Findings

- Refresh frequency is higher than necessary because `PrayerWidgetProvider.scheduleAllAlarms()` at `android\app\src\main\java\com\sadat\jamaattime\PrayerWidgetProvider.java:214`, `WidgetMaintenanceWorker.doWork()` at `android\app\src\main\kotlin\com\sadat\jamaattime\WidgetMaintenanceWorker.kt:13`, and `android:updatePeriodMillis` at `android\app\src\main\res\xml\prayer_widget_info.xml:9` all exist together.
- Native `RemoteViews` use `Chronometer`, which is good for per-second countdown without per-second Dart updates.
- The provider schedules boundary alarms for next prayer, next Jamaat, Jamaat-over, and midnight, which is the right direction, but the extra 15-minute maintenance worker should be reduced or scoped.
- `PrayerWidgetProvider.onReceive()` at `android\app\src\main\java\com\sadat\jamaattime\PrayerWidgetProvider.java:322` triggers a Dart refresh after boundary ticks; this is acceptable at boundaries but should not be combined with unnecessary periodic refreshes.
- `WidgetService.updateWidgetData()` writes many HomeWidget preferences in `lib\services\widget_service.dart:204` through `:267`, then calls `HomeWidget.updateWidget(...)` at `:269`. This should remain boundary-driven, not frequent.

## Notification Specific Findings

- `NotificationService.initialize()` at `lib\services\notification_service.dart:96` initializes plugins and creates channels before first frame because `main()` awaits it at `lib\main.dart:58`.
- `_createAllNotificationChannels()` at `lib\services\notification_service.dart:219` creates many Android channels. This does not need to block the first frame.
- `scheduleNotification()` uses `AndroidScheduleMode.exactAllowWhileIdle` at `lib\services\notification_service.dart:461`; this is acceptable only if the app keeps exact-alarm permissions justified and scheduling is not repeated unnecessarily.
- `scheduleAllNotifications()` at `lib\services\notification_service.dart:879` cancels all notifications at `:884`, then schedules prayer and Jamaat notifications. Avoid this unless inputs changed.
- FCM foreground image rendering downloads a remote image with a 10-second timeout in `lib\services\notifications\fcm_foreground_renderer.dart:67`. This is foreground-only, but keep image sizes constrained server-side.
- `fcmBackgroundHandler()` at `lib\services\notifications\fcm_background_handler.dart:11` only initializes Firebase, which is appropriately light.

## Battery Risk Assessment

- Highest battery risk: exact alarms plus 15-minute widget maintenance in `PrayerWidgetProvider`, `MainActivity`, and `WidgetMaintenanceWorker`.
- Home tab timer risk: one-second countdown timers continue while hidden due to `IndexedStack`.
- Animation risk: `ForbiddenTimesWidget` pulse animation repeats all day.
- Location risk: `LocationService.getCurrentPosition()` uses high GPS accuracy without timeout.
- Notification risk: `scheduleAllNotifications()` cancels/reschedules all notifications instead of diffing.
- Accessibility risk: `FocusGuardAccessibilityService` is scoped to YouTube only through `packageNames`, but `detectShorts()` recursively scans node trees up to depth 25 at `android\app\src\main\kotlin\com\sadat\jamaattime\focusguard\FocusGuardAccessibilityService.kt:97`. The 2-second debounce at `:22` helps; no immediate P0 battery issue if users do not enable Focus Guard.

## Memory Leak Risk Assessment

- `HomeScreen._timer` is cancelled in `HomeScreen.dispose()` at `lib\screens\home_screen.dart:1221`; no leak, but lifecycle pausing is missing.
- `HomeScreen._settingsSubscription` is cancelled at `lib\screens\home_screen.dart:1223`; acceptable.
- `PrayerCountdownWidget._timer` is cancelled at `lib\widgets\prayer_countdown_widget.dart:239`; no leak, but inactive-tab pause is missing.
- `SahriIftarWidget._timer` is cancelled at `lib\widgets\sahri_iftar_widget.dart:291`; no leak, but inactive-tab pause is missing.
- `_SahriIftarFullscreenPageState` cancels `_timer`, disposes `_pulseController`, removes observer, and disables wake lock at `lib\widgets\sahri_iftar_widget.dart:846`; acceptable.
- `ForbiddenTimesWidget` cancels `_refreshTimer` and disposes `_pulseController` at `lib\widgets\forbidden_times_widget.dart:163`; no leak, but animation runs unnecessarily while mounted.
- `FcmService` stores `_authSub` and `_tokenRefreshSub` and has `dispose()` at `lib\services\notifications\fcm_service.dart:197`, but listeners from `FirebaseMessaging.onMessage.listen(...)` at `:62` and `onMessageOpenedApp.listen(...)` at `:63` are not stored. Since `FcmService` is singleton-initialized once, this is low practical leak risk, but it should be cleaned if service reset/reinit is introduced.
- `BookmarkService._initAuthListener()` at `lib\services\bookmark_service.dart:25` does not store its auth subscription. Since it is singleton-owned for app lifetime, this is low risk, but avoid adding reset/reinit without subscription cleanup.

## Release Build Issues

- `flutter analyze` fails with 3 errors in `test_ebadat_service.dart`, so release automation should fail until fixed.
- `MaterialApp` in `lib\main.dart:116` does not set `debugShowCheckedModeBanner`; Flutter defaults to no banner in release, so no release debug banner issue.
- Release signing is configured and `android\key.properties` exists. `android\app\build.gradle.kts:56` uses release signing when the file exists; otherwise it falls back to debug signing at `:60`.
- Shrinking is disabled: `android\app\build.gradle.kts:62` and `:63`.
- APK size is 68.5 MB; AAB size is 54.2 MB.
- Debug/diagnostic logs are present in widget, Focus Guard, Jamaat service, notification service, and notice telemetry paths.
- The worktree is dirty before release: modified `lib\main.dart`, `lib\themes\green_theme.dart`, `lib\widgets\sahri_iftar_widget.dart`, `lib\widgets\shared_ui_widgets.dart`; untracked `jamaat_time_green_theme_visual_polish_plan.md` and `jamaat_time_main_card_premium_polish_plan.md`.
- `flutter pub outdated` reports major newer versions for Firebase, Google Fonts, file picker, share, package info, and notification dependencies. Do not upgrade immediately before release unless a specific bug requires it.

## Safe Minimal Fix Plan

1. Fix `flutter analyze` release blockers in `test_ebadat_service.dart` and `lib\main.dart`.
2. Remove or scope the unconditional 15-minute widget maintenance enqueue in `MainActivity.configureFlutterEngine()`.
3. Keep widget updates tied to next prayer, next Jamaat, Jamaat-over, and midnight. Cancel widget jobs/alarms when no widgets are enabled.
4. Review `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, and `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` in `AndroidManifest.xml`; keep only those with release-policy justification.
5. Move non-critical startup work out of `main()` after first frame: FCM topic/token writes, notification channel creation, and Google font preloading.
6. Add tab/app-lifecycle pause support for `PrayerCountdownWidget`, `SahriIftarWidget`, `LiveClockWidget`, and `ForbiddenTimesWidget`.
7. Stop `ForbiddenTimesWidget._pulseController` when no forbidden window is active.
8. Cache tomorrow Fajr in `PrayerCountdownWidget` after Isha.
9. Add timeout and lower-power accuracy to `LocationService.getCurrentPosition()`.
10. Test release shrinking with `android\app\proguard-rules.pro` before changing release defaults.

Rules for this fix plan:

- No unrelated refactor.
- No UI design rewrite.
- No prayer calculation change.
- No notification content change.
- No Firebase/FCM data model change.
- No accessibility behavior change.

## Files That Should Be Edited Later

- `test_ebadat_service.dart`
- `lib\main.dart`
- `lib\screens\home_screen.dart`
- `lib\widgets\prayer_countdown_widget.dart`
- `lib\widgets\sahri_iftar_widget.dart`
- `lib\widgets\live_clock_widget.dart`
- `lib\widgets\forbidden_times_widget.dart`
- `lib\services\location_service.dart`
- `lib\services\notification_service.dart`
- `lib\services\notifications\fcm_service.dart`
- `android\app\src\main\java\com\sadat\jamaattime\PrayerWidgetProvider.java`
- `android\app\src\main\kotlin\com\sadat\jamaattime\MainActivity.kt`
- `android\app\src\main\kotlin\com\sadat\jamaattime\WidgetMaintenanceWorker.kt`
- `android\app\src\main\AndroidManifest.xml`
- `android\app\build.gradle.kts`

## Files That Should Not Be Touched

- `lib\screens\admin_jamaat_panel.dart`
- `lib\screens\admin_auto_rules_screen.dart`
- `lib\screens\admin_tools_screen.dart`
- `lib\screens\admin_notification_broadcast_screen.dart`
- `lib\screens\admin_notification_history_screen.dart`
- `functions\src\**`
- `docs\**`
- `windows\**`
- `macos\**`
- `ios\**`
- `lib\data\**` except only if separately fixing lint noise
- `lib\services\prayer_time_engine.dart` unless only adding cache support without changing calculation semantics
- `lib\services\prayer_aux_calculator.dart` unless profiling proves it is needed

## Final Verdict

**Can this app be released now?**
Not yet. The APK and AAB build successfully, but analyzer errors and Android background scheduling policy/battery risks should be fixed first.

**What must be fixed first?**
Fix `flutter analyze`, reduce widget/background maintenance to boundary-driven updates, review exact-alarm/battery permissions, and defer heavy startup work until after first frame.

**What can wait?**
Dependency upgrades, release shrinking, visual shadow reductions, DateFormat micro-optimizations, and broader architecture cleanup can wait until after the release-critical fixes are complete.
