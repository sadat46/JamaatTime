# Task: Fix Android home-screen widget countdown not advancing to next prayer/jamaat

You are working in the `jamaat_time` Flutter app. Repo root is the current working directory. Implement the four-layer fix described below. Do **not** touch any iOS code, the in-app home screen countdown (`lib/widgets/prayer_countdown_widget.dart` and friends), or any notification logic. The in-app countdown already works; only the **Android home-screen widget** is broken.

## Symptom to fix

In the Android home-screen widget, the prayer-time countdown and the jamaat-time countdown both tick down to `00:00` and then **freeze**. They do not recalculate to the next prayer or the next jamaat when the boundary is crossed. Reproducible most reliably at Maghrib: prayer-end (Maghrib start) and Maghrib-jamaat are typically within 5 minutes of each other, and the second transition never happens.

## Why it happens (read this before changing code)

The widget renders countdowns as Android `Chronometer` views set up in `android/app/src/main/java/com/sadat/jamaattime/PrayerWidgetProvider.java::onUpdate()` (lines 70–84 and 79–84) with `setChronometerCountDown(true)`. A `Chronometer` ticks down to `00:00` and then **stays there** — there is no callback when it expires. The countdown only advances when `onUpdate()` runs again with fresh epoch values written by Dart.

Today, that re-entry depends on a single chain:

1. `scheduleBoundaryAlarm()` (lines 181–198) registers one `setExactAndAllowWhileIdle` PendingIntent at `min(prayerEpoch, jamaatEpoch, nextMidnight) + 1s`.
2. The PendingIntent targets `es.antonborri.home_widget.HomeWidgetBackgroundReceiver`.
3. That receiver dispatches `HomeWidgetBackgroundService` (a `JobService`).
4. The JobService cold-starts a Flutter background isolate.
5. The isolate runs `backgroundCallback` in `lib/services/widget_service.dart` (lines 27–138), which writes new prefs and calls `HomeWidget.updateWidget(...)`.
6. That re-invokes `onUpdate`, which schedules the *next* alarm.

Specific failure modes:

- **Only the earliest boundary is scheduled.** `getNextBoundaryEpoch` (lines 221–240) picks `min(prayer, jamaat, midnight)`. The next one is supposed to be scheduled by re-entrant `onUpdate`. If anything in steps 2–5 is delayed, no alarm exists for the second boundary at all.
- **Doze rate-limit.** `setExactAndAllowWhileIdle` is throttled to ~one fire per 9 minutes per app while the device is idle. Maghrib-end and Maghrib-jamaat are typically 5 minutes apart, so the second alarm cannot fire promptly.
- **Long, fragile chain.** Cold-starting a Flutter isolate from a JobService takes seconds and is heavily restricted on OEM-skinned Android (Xiaomi, Oppo, Samsung). When the app is force-stopped or swiped from recents, the pending alarm is cancelled outright.
- **No alarm exists for the `Ongoing → Over` transition.** `_jamaatOngoingWindow = Duration(minutes: 10)` in `widget_service.dart` is honored only when Dart re-runs; nothing schedules an alarm at `jamaatTime + 10 min`.
- **Self-heal gate is wrong.** `onUpdate` checks `running && nextEpoch <= now` to decide whether to self-heal (lines 59–61). After Dart writes Ongoing/Over, `running` is `false`, so `jamaatStale` is permanently `false` and self-heal cannot detect the missed transition. The gate must be epoch-based, not flag-based.

## Files you will touch

- **Edit** `android/app/src/main/java/com/sadat/jamaattime/PrayerWidgetProvider.java` (full rewrite of the alarm-scheduling section; new BOUNDARY_TICK action handler).
- **Edit** `android/app/src/main/AndroidManifest.xml` (add the new internal action to the existing `<receiver>` intent-filter; nothing else changes).
- **Edit** `lib/services/widget_service.dart` (expose `jamaat_over_epoch_millis` and stop hard-coding the 10-min window in Java).
- **Create** `android/app/src/main/kotlin/com/sadat/jamaattime/WidgetMaintenanceWorker.kt` (15-minute WorkManager safety net).
- **Edit** `android/app/src/main/kotlin/com/sadat/jamaattime/MainActivity.kt` (enqueue the worker on app start).
- **Edit** `android/app/build.gradle.kts` (add `androidx.work:work-runtime` if not present).

Do not change `android/app/src/main/res/xml/prayer_widget_info.xml` (leave the 30-min sweep) or the layout XML.

## Implementation

### Layer 1 — Multi-target, Doze-immune alarms (the core fix)

In `PrayerWidgetProvider.java`:

1. Add new constants:
   ```java
   private static final String ACTION_BOUNDARY_TICK = "com.sadat.jamaattime.action.BOUNDARY_TICK";
   private static final String EXTRA_TICK_KIND = "com.sadat.jamaattime.extra.TICK_KIND";
   private static final int REQ_PRAYER_BOUNDARY = 10;
   private static final int REQ_JAMAAT_BOUNDARY = 11;
   private static final int REQ_JAMAAT_OVER = 12;
   ```
   Keep the existing `ALARM_REQUEST_CODE = 2` only if needed for backward compatibility while migrating; otherwise remove it. Cancel the old PendingIntent in `onEnabled`/`onReceive(BOOT_COMPLETED|MY_PACKAGE_REPLACED)` to avoid stale entries.

2. Replace the single `scheduleBoundaryAlarm` with three independent scheduling calls. Each builds its own PendingIntent targeting **`PrayerWidgetProvider` itself** (not `HomeWidgetBackgroundReceiver`):
   ```java
   private PendingIntent buildSelfTickIntent(Context ctx, int requestCode, String kind) {
       Intent intent = new Intent(ctx, PrayerWidgetProvider.class)
           .setAction(ACTION_BOUNDARY_TICK)
           .putExtra(EXTRA_TICK_KIND, kind);
       return PendingIntent.getBroadcast(
           ctx, requestCode, intent,
           PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
   }
   ```
   Schedule:
   - prayer boundary: `nextEpoch + 1000` if `nextEpoch > now`
   - jamaat boundary: `jamaatEpoch + 1000` if `jamaatEpoch > now`
   - jamaat-over: `jamaatOverEpoch + 1000` if `jamaatOverEpoch > now` (read from new pref `jamaat_over_epoch_millis`; see Layer 4)
   - keep the existing midnight alarm as a low-priority backup

3. Switch the prayer/jamaat/jamaat-over alarms to **`setAlarmClock`** because it is exempt from Doze, app-standby buckets, and the 9-minute rate limit:
   ```java
   AlarmManager.AlarmClockInfo info =
       new AlarmManager.AlarmClockInfo(fireAt, /*showIntent*/ null);
   am.setAlarmClock(info, pi);
   ```
   Wrap in `try { ... } catch (SecurityException e)` and on failure fall back to `setExactAndAllowWhileIdle`, then `setAndAllowWhileIdle`. Log which path was taken.

4. **Important behavior change in `onReceive`:** when `intent.getAction().equals(ACTION_BOUNDARY_TICK)`, do two things, in this order:
   a. Pull the latest `int[] widgetIds = AppWidgetManager.getInstance(ctx).getAppWidgetIds(new ComponentName(ctx, PrayerWidgetProvider.class));` and call `onUpdate(ctx, mgr, widgetIds)` immediately. This re-renders the chronometer from current prefs (placeholder if the next epoch isn't yet known) and re-arms the next alarm — independent of Dart cold-start.
   b. Call `triggerDartRefresh(ctx)` so Dart recomputes and rewrites prefs. When Dart finishes, `HomeWidget.updateWidget` will trigger another `onUpdate` with fresh values. This is the "two passes" pattern: render-now, refresh-properly-soon.

5. Fix the self-heal gate (currently lines 59–61). Change from flag-based to epoch-based:
   ```java
   boolean prayerStale = nextEpoch > 0L && nextEpoch + 1000L <= nowMillis;
   boolean jamaatStale = jamaatEpoch > 0L && jamaatEpoch + 1000L <= nowMillis;
   ```
   `running` and `jamaatRunning` should still be respected for the *render* decision (whether to start a chronometer), but **not** for deciding whether to self-heal.

6. Cancel all three new alarms in `onDisabled` (the existing `cancelBoundaryAlarm` only cancels one). Add a `cancelAllAlarms` helper.

### Layer 2 — Render-on-expire fallback

Inside `onUpdate`, when a chronometer is being started, *also* schedule the corresponding self-tick alarm from Layer 1. Crucially, in the **else branch** where the chronometer would otherwise be set to `-`:

- If `nextEpoch > 0` (a boundary is known but in the past), schedule a `BOUNDARY_TICK` for `now + 1500ms` so the next pass re-renders with whatever Dart has produced, instead of leaving a `-` indefinitely.
- Render placeholder text `"…"` (or the existing `-`) but do not stop scheduling.

The intent is: even if Dart's recompute is delayed for any reason, the widget visibly leaves `00:00` and the alarm cascade keeps running.

### Layer 3 — WorkManager periodic safety net

1. Add the dependency in `android/app/build.gradle.kts`:
   ```kotlin
   dependencies {
       implementation("androidx.work:work-runtime:2.9.1")
       coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
   }
   ```

2. Create `android/app/src/main/kotlin/com/sadat/jamaattime/WidgetMaintenanceWorker.kt`:
   ```kotlin
   package com.sadat.jamaattime

   import android.content.ComponentName
   import android.content.Context
   import android.content.Intent
   import android.net.Uri
   import androidx.work.CoroutineWorker
   import androidx.work.WorkerParameters

   class WidgetMaintenanceWorker(ctx: Context, params: WorkerParameters)
       : CoroutineWorker(ctx, params) {

       override suspend fun doWork(): Result {
           val ctx = applicationContext
           val intent = Intent("es.antonborri.home_widget.action.BACKGROUND")
               .setComponent(ComponentName(
                   ctx, "es.antonborri.home_widget.HomeWidgetBackgroundReceiver"))
               .setData(Uri.parse("homewidget://maintenance"))
           ctx.sendBroadcast(intent)
           return Result.success()
       }
   }
   ```

3. Schedule it from `MainActivity.configureFlutterEngine` and from `PrayerWidgetProvider.onEnabled`. Use a unique periodic work name (`"widget_maintenance"`) and `ExistingPeriodicWorkPolicy.UPDATE` so re-enqueuing is idempotent. Interval: 15 minutes (the Android minimum). The worker simply broadcasts the same intent that the alarm chain uses — it does not need to know prayer-time logic.

### Layer 4 — Expose `jamaat_over_epoch_millis` from Dart

In `lib/services/widget_service.dart`:

1. In `WidgetPreviewData`, add a field `final int jamaatOverEpochMillis;` (default `0`).
2. In `_computeJamaatWidgetState`, when the state is the active countdown branch (`now.isBefore(jamaatTime)`), compute `jamaatTime.add(_jamaatOngoingWindow).millisecondsSinceEpoch` and propagate it through `_JamaatWidgetState` and `WidgetPreviewData`. In all other branches return `0`.
3. In `updateWidgetData`, write a new pref:
   ```dart
   HomeWidget.saveWidgetData<int>(
     'jamaat_over_epoch_millis',
     widgetData.jamaatOverEpochMillis,
   ),
   ```
4. In `PrayerWidgetProvider.java`, read this with the existing `readEpochMillis(prefs, "jamaat_over_epoch_millis")` and pass it into the new scheduler.
5. Update existing tests in `test/services/widget_service_test.dart` (if present — search for `WidgetPreviewData` or `computeWidgetPreviewData` and add the new field; do not invent tests if the file does not exist).

### Manifest change

In `android/app/src/main/AndroidManifest.xml`, the existing `<receiver android:name=".PrayerWidgetProvider" ...>` already declares the actions for boot/replace/appwidget. Add one more `<action>` inside the same `<intent-filter>`:

```xml
<action android:name="com.sadat.jamaattime.action.BOUNDARY_TICK" />
```

Nothing else in the manifest changes.

## Constraints and guardrails

- **Do not modify Dart logic for the in-app home countdown.** The user reports the in-app countdown works; only the Android widget is broken.
- **Do not change `prayer_widget_info.xml`'s `updatePeriodMillis`.** It's a useful fallback.
- **Do not remove the existing `triggerDartRefresh` path.** Layer 1 keeps it but invokes it from inside `ACTION_BOUNDARY_TICK` handling, after the synchronous re-render.
- **Keep `FLAG_IMMUTABLE` on every PendingIntent** — required on Android 12+.
- **Do not introduce a foreground service.** The fix must be invisible to the user (no persistent notification).
- **Preserve backward compatibility.** A widget already placed on the user's home screen must keep working after upgrade. That means: cancel the old `ALARM_REQUEST_CODE = 2` alarm explicitly during upgrade (in `onReceive` for `MY_PACKAGE_REPLACED`) so it doesn't double-fire alongside the new ones.
- **Do not change the home_widget plugin version.** Stay on `home_widget: ^0.9.0`.
- **Compile target.** Java 11, minSdk 24, and the project uses `flutter.compileSdkVersion`/`flutter.targetSdkVersion`. Don't pin SDK versions yourself.

## Verification

After implementing, run these checks and include the results in your final summary:

1. **Static check.** `cd android && ./gradlew :app:compileDebugJavaWithJavac :app:compileDebugKotlin` succeeds. Report any warnings introduced.
2. **Dart analyzer.** `flutter analyze` shows no new warnings or errors in `lib/services/widget_service.dart`.
3. **Targeted tests.** If `test/services/widget_service_test.dart` exists, run `flutter test test/services/widget_service_test.dart`. If it doesn't, do not create speculative tests — note the absence and stop.
4. **Manual repro plan** (document this in the PR description, do not run it):
   - Set device clock 1 minute before Maghrib. Place the widget on the home screen. Wait through Maghrib boundary and Maghrib-jamaat boundary. Both chronometers must reset and resume counting toward the next boundary.
   - Repeat with the app force-stopped after Layer 3 lands. The widget must repair within ~15 minutes.
5. **Logging.** Add `Log.d(TAG, "alarm scheduled kind=<prayer|jamaat|over> in <N>s via <setAlarmClock|exactIdle|inexactIdle>")` so `adb logcat -s PrayerWidgetProvider` shows which path was taken and which alarm fired.

## Output expectations

- Make the changes file by file, smallest first.
- After each file, briefly summarize what changed and why (one or two sentences).
- At the end, output the manual repro plan from step 4 above as a final block, ready to paste into the PR description.
- Do not commit. Leave the working tree dirty for review.
