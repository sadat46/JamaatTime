# Task: Finish the Android widget countdown fix — resolve PendingIntent collision

The previous fix landed the Layer 1–4 skeleton but contains one critical defect that prevents the widget from actually advancing past `00:00`, plus one minor gap. This task closes both. Do **not** touch iOS, `lib/widgets/prayer_countdown_widget.dart`, or any notification logic.

## What's wrong with the current implementation

`android/app/src/main/java/com/sadat/jamaattime/PrayerWidgetProvider.java`:

1. **(critical) PendingIntent collision on request code 10.** `scheduleAllAlarms` (lines 209–230) builds the prayer-boundary alarm and the midnight fallback alarm with the **same** `REQ_PRAYER_BOUNDARY = 10`. Android's `PendingIntent.getBroadcast` deduplicates on `(requestCode, Intent.filterEquals)`, and `Intent.filterEquals` ignores extras — so the only difference (`EXTRA_TICK_KIND`) doesn't disambiguate. Both calls return the **same** PendingIntent.

   `AlarmManager.set*(...)` is documented to cancel any existing alarm bound to the same IntentSender before installing the new one. So the call order in `scheduleAllAlarms` is:

   - `setAlarmClock(prayerEpoch + 1s, prayer-PI)` — schedules the boundary alarm.
   - `setAndAllowWhileIdle(midnight, midnight-PI)` — same IntentSender → **cancels the prayer alarm** and replaces it with the midnight alarm.

   Net result every time `onUpdate` runs: the prayer-boundary alarm is wiped out. The chronometer ticks to `00:00` and stays there until 00:00 local. The original bug is not actually fixed.

2. **(critical, same root cause) Layer 2 re-tick is also clobbered.** The expire-branch re-tick at line 95 reuses `REQ_PRAYER_BOUNDARY`; same goes for the jamaat re-tick at line 123 reusing `REQ_JAMAAT_BOUNDARY`. The midnight schedule wipes the prayer re-tick; in the symmetric case where both jamaat boundary and over alarms are due, request-code reuse can also cause unintended replacement.

3. **(minor) Fresh-install widget has no WorkManager safety net.** `MainActivity.configureFlutterEngine` enqueues the periodic worker correctly, but `PrayerWidgetProvider.onEnabled` does not. A user who places the widget without opening the app gets no Layer 3 backup.

Everything else from the previous fix is correct and should be left alone:

- `setAlarmClock` with `setExactAndAllowWhileIdle` → `setAndAllowWhileIdle` fallback chain.
- `ACTION_BOUNDARY_TICK` action and the two-pass handler (`onReceive` lines 330–341).
- Epoch-based self-heal gate (lines 72–73).
- Legacy `ALARM_REQUEST_CODE = 2` cancellation on boot/replace.
- `FLAG_IMMUTABLE` on every PendingIntent.
- `_JamaatWidgetState.overEpochMillis` and the `jamaat_over_epoch_millis` pref.
- `WidgetMaintenanceWorker` and the `androidx.work:work-runtime:2.9.1` dependency.

## Implementation

### Step 1 — Add three new request-code constants

In `PrayerWidgetProvider.java`, immediately below the existing block at lines 26–31:

```java
// Distinct PendingIntent slots — must NOT share request codes, otherwise
// later setX() calls cancel earlier ones (Intent.filterEquals ignores extras).
private static final int REQ_MIDNIGHT             = 13;
private static final int REQ_PRAYER_EXPIRE_TICK   = 14;
private static final int REQ_JAMAAT_EXPIRE_TICK   = 15;
```

Do not change the existing `REQ_PRAYER_BOUNDARY = 10`, `REQ_JAMAAT_BOUNDARY = 11`, or `REQ_JAMAAT_OVER = 12` values.

### Step 2 — Use a separate slot for the midnight alarm

In `scheduleAllAlarms` (currently around lines 223–229), replace the midnight block with:

```java
// Midnight fallback — distinct slot so it cannot cancel the prayer-boundary alarm.
long midnight = getNextMidnightEpoch(nowMillis);
AlarmManager am = (AlarmManager) ctx.getSystemService(Context.ALARM_SERVICE);
if (am != null && midnight > nowMillis) {
    PendingIntent midPi = buildSelfTickIntent(ctx, REQ_MIDNIGHT, "midnight");
    am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, midnight, midPi);
}
```

Only the request code passed to `buildSelfTickIntent` changes (`REQ_PRAYER_BOUNDARY` → `REQ_MIDNIGHT`).

### Step 3 — Use distinct slots for Layer 2 expire re-ticks

In `onUpdate`'s prayer-expire branch (currently lines 90–97), change:

```java
buildSelfTickIntent(context, REQ_PRAYER_BOUNDARY, "prayer"),
"prayer-expire");
```

to

```java
buildSelfTickIntent(context, REQ_PRAYER_EXPIRE_TICK, "prayer-expire"),
"prayer-expire");
```

In the jamaat-expire branch (currently lines 119–125), change:

```java
buildSelfTickIntent(context, REQ_JAMAAT_BOUNDARY, "jamaat"),
"jamaat-expire");
```

to

```java
buildSelfTickIntent(context, REQ_JAMAAT_EXPIRE_TICK, "jamaat-expire"),
"jamaat-expire");
```

The `kind` extra is also retitled so logs distinguish the two cases.

### Step 4 — Cancel all four extra slots in `cancelAllAlarms`

Update `cancelAllAlarms` (currently lines 232–240) so every distinct request code is explicitly cancelled. The legacy cancel must remain. Final body:

```java
private void cancelAllAlarms(Context context) {
    AlarmManager am = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
    if (am == null) return;
    am.cancel(buildSelfTickIntent(context, REQ_PRAYER_BOUNDARY,    "prayer"));
    am.cancel(buildSelfTickIntent(context, REQ_JAMAAT_BOUNDARY,    "jamaat"));
    am.cancel(buildSelfTickIntent(context, REQ_JAMAAT_OVER,        "over"));
    am.cancel(buildSelfTickIntent(context, REQ_MIDNIGHT,           "midnight"));
    am.cancel(buildSelfTickIntent(context, REQ_PRAYER_EXPIRE_TICK, "prayer-expire"));
    am.cancel(buildSelfTickIntent(context, REQ_JAMAAT_EXPIRE_TICK, "jamaat-expire"));
    // Legacy alarm that targeted HomeWidgetBackgroundReceiver in older builds.
    am.cancel(buildLegacyBoundaryPendingIntent(context));
}
```

The `kind` extra is irrelevant for cancellation (filterEquals ignores it) but is kept consistent for clarity.

### Step 5 — Schedule the maintenance worker from `onEnabled`

`PrayerWidgetProvider.onEnabled` is currently a stub. Make it enqueue the same periodic work that `MainActivity` enqueues, so users who place the widget without opening the app are still covered. Use `ExistingPeriodicWorkPolicy.KEEP` here (not `UPDATE`) — `MainActivity` already uses `UPDATE` and we don't want `onEnabled` to repeatedly reset the worker's schedule.

```java
@Override
public void onEnabled(Context context) {
    super.onEnabled(context);
    Log.d(TAG, "Widget enabled");
    try {
        androidx.work.PeriodicWorkRequest req =
            new androidx.work.PeriodicWorkRequest.Builder(
                WidgetMaintenanceWorker.class, 15, java.util.concurrent.TimeUnit.MINUTES
            ).build();
        androidx.work.WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            "widget_maintenance",
            androidx.work.ExistingPeriodicWorkPolicy.KEEP,
            req);
    } catch (Throwable t) {
        Log.w(TAG, "Failed to enqueue maintenance worker from onEnabled", t);
    }
}
```

(Use fully-qualified names to avoid touching the import block; or hoist them to imports if the existing style prefers that.)

### Step 6 — Sanity-check the receive path

No code change required, but confirm by reading:

- `onReceive` correctly compares `intent.getAction()` against `ACTION_BOUNDARY_TICK` regardless of which `kind` extra was set, so the new `REQ_MIDNIGHT` / `REQ_*_EXPIRE_TICK` alarms fire through the same handler. The handler does not branch on `kind`; that's fine — it always re-renders and triggers a Dart refresh.

## Constraints

- Do not change any other request code, action name, or pref key.
- Do not introduce new manifest entries; the existing `<action android:name="com.sadat.jamaattime.action.BOUNDARY_TICK" />` already covers all six request codes since they share the action.
- Keep `FLAG_IMMUTABLE` on every PendingIntent.
- Do not bump `home_widget`, `androidx.work`, or any Flutter package version.
- Do not delete the legacy cancel path — users on older app versions need it on the next upgrade.

## Verification

1. **Static check.** `cd android && ./gradlew :app:compileDebugJavaWithJavac :app:compileDebugKotlin` succeeds, no new warnings.
2. **Dart analyzer.** `flutter analyze` clean. (No Dart files change in this task.)
3. **Tests.** `flutter test test/services/widget_service_test.dart` — should still pass; this task does not touch Dart.
4. **Targeted manual repro.** Set device clock to one minute before Maghrib. Place the widget and lock the screen. Wait through the Maghrib boundary, then through the Maghrib-jamaat boundary. Both chronometers must reset and resume counting toward the next boundary; neither should sit at `00:00` for more than a few seconds. Repeat with the app force-stopped — Layer 3 should repair the widget within 15 minutes.
5. **Logcat assertion.** Run `adb logcat -s PrayerWidgetProvider` during the repro. Expect to see, in order: `alarm scheduled kind=prayer`, `alarm scheduled kind=jamaat`, `alarm scheduled kind=over`, `alarm scheduled kind=midnight`, then a `BOUNDARY_TICK received kind=prayer` (or `jamaat`/`over`) at the boundary. Critically: each alarm-scheduled line should appear once per `onUpdate` and the `kind=prayer` alarm line must not be followed immediately by a "cancel" for the same slot caused by the midnight schedule.
6. **Negative test for the original bug.** Confirm via `dumpsys alarm | grep com.sadat.jamaattime` immediately after `onUpdate` runs that **four** alarms are pending for the package (prayer, jamaat, over when applicable, midnight), not one.

## Output expectations

- Edit `PrayerWidgetProvider.java` only (six small edits per the steps above).
- After the change, summarize in three lines: what was wrong, what changed, and the expected logcat signature during a successful boundary transition.
- Do not commit. Leave the working tree dirty.
