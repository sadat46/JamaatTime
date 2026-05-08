# Task: Move Android widget state computation to native Kotlin

The Android home-screen widget freezes at `00:00` (or `-`) when the app is closed. Previous fixes made the AlarmManager chain reliable — alarms *do* fire at the boundary — but `onUpdate` reads SharedPreferences that were written by Dart the last time the app was open. When the app is closed, the cold-start of the home_widget background isolate fails under Doze / OEM battery savers, prefs never get refreshed, and the widget stays on stale state. The fix is to make the widget compute its own state in Kotlin from raw prayer/jamaat epochs that Dart wrote earlier, with no Dart roundtrip at the boundary.

Do **not** touch iOS, the in-app countdown widgets, notifications, or the prayer-time calculation logic in `lib/services/prayer_time_engine.dart` and `lib/services/prayer_aux_calculator.dart`. The only Dart change is to write a wider data contract; everything else moves to native.

## Files

- **Replace body of** `android/app/src/main/java/com/sadat/jamaattime/PrayerWidgetProvider.java` — convert to Kotlin in place at `android/app/src/main/kotlin/com/sadat/jamaattime/PrayerWidgetProvider.kt`. **Critical:** the registered class FQCN in the manifest is `com.sadat.jamaattime.PrayerWidgetProvider`. Existing widgets on user home screens are pinned to that FQCN. The Kotlin class **must** keep the same package + class name. Delete the old `.java` file after creating the `.kt` file in the same package. Do not change the manifest `<receiver android:name=".PrayerWidgetProvider">` line.
- **Create** `android/app/src/main/kotlin/com/sadat/jamaattime/WidgetState.kt` — pure data + state-machine, no Android imports. Unit-testable.
- **Edit** `android/app/src/main/kotlin/com/sadat/jamaattime/WidgetMaintenanceWorker.kt` — stop broadcasting the home_widget background action; instead broadcast `ACTION_BOUNDARY_TICK` directly to `PrayerWidgetProvider`. Keep the 6-hour cadence.
- **Edit** `android/app/src/main/AndroidManifest.xml` — add `android.intent.action.TIME_SET`, `android.intent.action.TIMEZONE_CHANGED`, `android.intent.action.DATE_CHANGED` to the existing `<receiver>` intent-filter. Nothing else changes in the manifest.
- **Edit** `lib/services/widget_service.dart` — write the new raw + localized payload (see "Data contract" below). Keep the existing computed prefs (`prayer_name`, `jamaat_label`, etc.) for backward compatibility during the upgrade window — the Kotlin code will ignore them, but old installs that race the upgrade should still render reasonably.
- **Edit** `test/services/widget_service_test.dart` — add tests for the new raw payload keys.
- **Create** `android/app/src/test/java/com/sadat/jamaattime/WidgetStateTest.kt` — unit tests for the state machine ported from `widget_service.dart::_computeJamaatWidgetState`. Use plain JVM JUnit; no instrumentation.

Do not rename to `JamaatWidgetProvider`, do not split into `WidgetRefreshScheduler` / `WidgetRefreshReceiver` / `WidgetBootReceiver` — keep everything the existing `PrayerWidgetProvider` did, and centralize the alarm helpers as private functions in the same file (or in `WidgetState.kt` if pure). The previous file split would orphan existing widget instances.

## Data contract Dart writes (the **only** Dart-side change)

In `WidgetService.updateWidgetData`, after the existing `Future.wait` block, also write the following keys via `HomeWidget.saveWidgetData`. Use the exact key names below — the Kotlin reader expects them.

**Raw epoch keys (long, milliseconds since epoch, 0 if unknown):**

```
epoch_fajr_today
epoch_sunrise_today
epoch_dhuhr_today
epoch_asr_today
epoch_maghrib_today
epoch_isha_today
epoch_fajr_tomorrow
jamaat_epoch_fajr_today
jamaat_epoch_dhuhr_today
jamaat_epoch_asr_today
jamaat_epoch_maghrib_today
jamaat_epoch_isha_today
last_compute_day_epoch     # local-midnight epoch of `date` argument; native uses this to detect day rollover
```

`epoch_fajr_tomorrow` comes from the `tomorrowFajr` argument already passed in. The five jamaat epochs come from resolving `jamaatTimes` per prayer using the existing `_resolveTodayJamaatTime` / `_parseTodayJamaatTime` helpers — extract them into a small public helper if needed, but keep the parser in Dart.

**Localization payload (string, all pre-localized to current `locale`):**

```
loc_prayer_fajr        loc_prayer_sunrise   loc_prayer_dhuhr
loc_prayer_asr         loc_prayer_maghrib   loc_prayer_isha
loc_jamaat_in_suffix         # AppText.widget_jamaatInSuffix
loc_jamaat_ongoing           # AppText.widget_jamaatOngoing
loc_jamaat_over              # AppText.widget_jamaatOver
loc_jamaat_na                # AppText.widget_jamaatNA
loc_prayer_ends_in           # AppText.widget_prayerEndsIn
loc_next_prayer_in_template  # AppText.widget_nextPrayerIn raw template; native substitutes {prayer}
loc_next_prayer_jamaat_template # AppText.widget_nextPrayerJamaatAt raw template; native substitutes {prayer} {time}
locale_code                  # "en" or "bn"
time_format_pattern          # "HH:mm" today (for native to format jamaat-at line)
```

For the templates: change the AppText getters that take parameters to also expose a raw-template form (search for `widget_nextPrayerIn` and `widget_nextPrayerJamaatAt` in the generated localizations). If exposing a raw template is awkward, fall back to passing each placeholder substituted with a literal sentinel like `{0}` and `{1}` and have Kotlin replace those.

**Keep `islamic_date`, `location`, and the `row_label_<n>` / `row_time_<n>` keys exactly as they are written today** — they are already pre-localized and pre-formatted in Dart. The 4-row grid will continue to be excluded-by-Dart based on whatever Dart thinks the current main prayer is. That is fine and correct: native does **not** need to recompute the row grid because the rows display *future* times that don't change within a day. The grid only becomes wrong on day rollover, which is when Dart will run again (see "When Dart runs" below).

## Native state machine (`WidgetState.kt`)

Pure Kotlin object with this signature:

```kotlin
data class RawSchedule(
    val today: Map<String, Long>,        // "Fajr"->epoch, "Sunrise"->epoch, ...
    val fajrTomorrow: Long,
    val jamaatToday: Map<String, Long>,  // "Fajr"->jamaat-epoch (or 0L), ...
    val computeDay: Long,                // last_compute_day_epoch
    val locale: Localization,
    val timeFormatPattern: String,
)

data class Localization(
    val prayerName: Map<String, String>, // "Fajr" -> localized
    val jamaatInSuffix: String, val jamaatOngoing: String,
    val jamaatOver: String, val jamaatNa: String,
    val prayerEndsIn: String,
    val nextPrayerInTemplate: String,        // "Coming {0}" or similar — {0} = prayer name
    val nextPrayerJamaatTemplate: String,    // "{0} Jamaat at {1}" — {0}=prayer, {1}=time
    val localeCode: String,                  // "en" | "bn"
)

data class RenderState(
    val prayerName: String,            // for prayer_name TextView
    val prayerTimeLabel: String,       // for prayer_time TextView (HH:mm or BN digits)
    val remainingLabel: String,        // for remaining_label TextView
    val countdownEpoch: Long,           // > 0 if Chronometer should run; 0 if not
    val jamaatLabel: String,
    val jamaatValueText: String,        // empty if countdown running
    val jamaatCountdownEpoch: Long,
    val jamaatTextUsesTimeStyle: Boolean,
)

object WidgetState {
    fun compute(now: Long, raw: RawSchedule): RenderState
    fun nextBoundaryEpoch(now: Long, raw: RawSchedule): Long  // for alarm scheduling
}
```

`compute` ports `WidgetService.computeWidgetPreviewData` + `_computeJamaatWidgetState` + `_computeSunriseJamaatWidgetState` from `lib/services/widget_service.dart` (lines 304–527). Mirror these constants and lists at the top of `WidgetState.kt`:

```kotlin
val periodOrder = listOf("Fajr","Sunrise","Dhuhr","Asr","Maghrib","Isha")
val mainPrayerOrder = listOf("Fajr","Dhuhr","Asr","Maghrib","Isha")
val jamaatOngoingWindowMs = 10L * 60 * 1000  // mirror _jamaatOngoingWindow
```

**State branches that must all be ported (do not skip any):**

1. `currentPeriod == "Sunrise"` — call sunrise branch; jamaat shows static "next prayer Jamaat at HH:MM" line; countdown is to next prayer; `jamaatTextUsesTimeStyle = false`. (Mirrors `_computeSunriseJamaatWidgetState`.)
2. `currentPeriod == "Isha" && now < Fajr_today` — overnight Isha. Jamaat → Over. Prayer countdown → `fajrTomorrow`. (Mirrors `widget_service.dart` lines 458–467 and 326–334.)
3. Active jamaat countdown: `now < jamaatTime`. Set `jamaatCountdownEpoch = jamaatTime`, `countdownRunning = true`, `textUsesTimeStyle = false`. (Mirrors lines 478–488.)
4. Ongoing window: `jamaatTime ≤ now < jamaatTime + 10 min`. Show "ongoing", `valueText = jamaatOngoing`, no countdown, `textUsesTimeStyle = true`. (Mirrors lines 490–491.)
5. Over: `now ≥ jamaatTime + 10 min`. Show "ended", same shape as Ongoing but with `jamaatOver` value. (Mirrors lines 492–493.)
6. No jamaat resolved → `Jamaat N/A`. (Mirrors lines 469–476.)

**Prayer countdown target:**

- Find first period in `periodOrder` whose epoch is `> now`. That's `nextPeriod`.
- If `nextPeriod` is null AND we are after Isha, target = `fajrTomorrow`.
- `countdownEpoch = max(0, target)`. `countdownRunning = countdownEpoch > now`.

**Bangla digit conversion** — if `localeCode == "bn"`, after formatting `HH:mm`, replace `0`–`9` with `০-৯`. That's enough for the widget; we don't need full `LocaleDigits.localize`. Implement a 16-line helper.

**No Hijri / Bangla-calendar code in Kotlin.** That string is already pre-formatted in `islamic_date` pref; native just reads it.

## `nextBoundaryEpoch`

Compute the smallest of:

- All today's prayer-period epochs that are `> now`
- `fajrTomorrow` if all of today's are past
- All today's jamaat epochs that are `> now`
- For each jamaat epoch, also `jamaat + 10 min` if that's still `> now` (the Ongoing → Over transition)
- Next local midnight

Return that single epoch + 1 s. The provider will schedule one alarm per call; on each tick the next boundary is recomputed. (This deliberately collapses the multi-alarm scheme of the prior fix back into a single self-rearming alarm — simpler, and now reliable because *every* tick re-renders correctly.)

## `PrayerWidgetProvider.kt` shape

Keep the same shell as the existing Java file, but:

- `onUpdate` reads the raw schedule + localization from prefs, calls `WidgetState.compute(now, raw)`, applies the resulting `RenderState` to `RemoteViews`, then schedules one alarm at `WidgetState.nextBoundaryEpoch(now, raw) + 1000L`.
- The Chronometer rendering stays exactly as today (`setChronometerCountDown(true)` + `setChronometer(base, ...)`). Compute `base = SystemClock.elapsedRealtime() + (countdownEpoch - now)` when `countdownEpoch > now`; otherwise show "-" and rely on the alarm to re-render.
- **Do not** schedule a Layer 2 expire-tick — there is no longer a "stuck on -" failure mode, because native always knows the current state. Drop the `REQ_PRAYER_EXPIRE_TICK` / `REQ_JAMAAT_EXPIRE_TICK` constants and their schedule sites.
- Keep the legacy alarm cancel on `BOOT_COMPLETED` / `MY_PACKAGE_REPLACED` so users upgrading from the previous build don't get duplicate ghost alarms.
- Use `Intent(ctx, PrayerWidgetProvider::class.java).setAction(ACTION_BOUNDARY_TICK)`. One request code: `REQ_BOUNDARY = 10`. With one PendingIntent the collision class of bug from the prior round can't recur.
- Self-rearming: in the `onReceive` branch for `ACTION_BOUNDARY_TICK`, just call `onUpdate` and let `onUpdate` schedule the next alarm. No Dart trigger at the boundary.

## When Dart runs

Dart's `backgroundCallback` is **only** invoked:

- Once a day, at the first widget tick after local midnight (native detects this by comparing `now`'s local-day-start against `last_compute_day_epoch`; if they differ, fire `triggerDartRefresh` exactly once).
- On `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, `TIME_SET`, `TIMEZONE_CHANGED`, `DATE_CHANGED` (clock or zone moved → schedule must be recomputed).
- When the user taps the in-widget refresh button (existing `refresh_button` PendingIntent — keep as is).
- From `WidgetMaintenanceWorker` only as a daily-rollover safety, not every 6 hours; instead the worker should broadcast `ACTION_BOUNDARY_TICK`, and Dart will be invoked through the day-rollover branch above if it's actually a new day.

This means a closed app survives an entire day with the alarm chain running purely in native, and Dart cold-start is only required at the day boundary — which has 24 hours of slack in case of OEM throttling.

## Android 12+ exact alarm

Already correct in the existing code (`canScheduleExactAlarms()` gate around `setExactAndAllowWhileIdle`, fallback to `setAndAllowWhileIdle`). Port that helper into the Kotlin file unchanged. Do not request the permission at runtime; the manifest already declares `USE_EXACT_ALARM` and `SCHEDULE_EXACT_ALARM`.

## Manifest

Inside the existing `<receiver android:name=".PrayerWidgetProvider" ...>` `<intent-filter>`, add:

```xml
<action android:name="android.intent.action.TIME_SET" />
<action android:name="android.intent.action.TIMEZONE_CHANGED" />
<action android:name="android.intent.action.DATE_CHANGED" />
```

Keep the existing `APPWIDGET_UPDATE`, `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED`, and `com.sadat.jamaattime.action.BOUNDARY_TICK` actions.

## Logging

In `PrayerWidgetProvider.kt`:

- `onUpdate` logs `"render now=<epoch> currentPeriod=<X> nextBoundary=<epoch> countdownEpoch=<epoch> jamaatState=<countdown|ongoing|over|na|sunrise>"`.
- `scheduleBoundaryAlarm` logs `"alarm scheduled in <N>s via <exactIdle|inexactIdle>"`.
- `onReceive` logs the action and, for `BOUNDARY_TICK`, whether it triggered a day-rollover Dart refresh.

All under tag `PrayerWidgetProvider`, gated by `Log.isLoggable`, so release builds stay quiet.

## Constraints

- **Do not change UI** — `prayer_widget.xml`, the launcher, or any string resources (Dart still owns the string content via the prefs payload).
- **Do not modify** `lib/services/prayer_time_engine.dart`, `lib/services/prayer_aux_calculator.dart`, `lib/services/jamaat_service.dart`, or any notification code.
- **Do not change** the home_widget plugin version.
- **Do not request** runtime permissions.
- **Keep** `Chronometer` for the live tick. Replacing it with a `TextView` + per-minute alarm is a regression and violates "Do not refresh every minute".
- **Do not delete** the existing computed-text prefs on the Dart side (`prayer_name`, `jamaat_label`, etc.). Keep writing them. The Kotlin code will ignore them; this preserves rollback safety.
- **All `PendingIntent`s** must use `FLAG_IMMUTABLE`.
- **Java 11** target; the project does not use Kotlin 1.9 features, stay conservative.

## Verification

1. **Unit tests** — `cd android && ./gradlew :app:testDebugUnitTest` runs `WidgetStateTest`. Cover at minimum: before-jamaat, ongoing window, over window, sunrise period, overnight Isha, no-jamaat, day-rollover detection, Bangla digits.
2. **Static check** — `./gradlew :app:compileDebugKotlin :app:compileDebugJavaWithJavac` clean.
3. **Dart analyzer + tests** — `flutter analyze` clean; `flutter test test/services/widget_service_test.dart` passes (extend the file to assert the new raw + localization keys are written).
4. **Manual repro** (document in PR; do not execute):
   - Force-stop the app, place the widget, watch through Maghrib + Maghrib jamaat. Both transitions must occur with the app stopped.
   - Repeat across midnight to validate the day-rollover Dart-trigger path.
   - Toggle device timezone; widget must re-render within seconds (TIMEZONE_CHANGED).
   - Toggle device locale to Bangla; verify next render shows Bangla digits and labels (this requires reopening the app once so Dart writes the Bangla payload — that's expected behavior).
5. **Pending alarm assertion** — after `onUpdate`, `adb shell dumpsys alarm | grep com.sadat.jamaattime` must show exactly **one** pending alarm for `ACTION_BOUNDARY_TICK` (not multiple, not zero).
6. **No-Dart soak** — clear app data so Dart prefs are empty, place the widget, then open the app exactly once. From that moment onward force-stop the app and leave the device idle for 24 hours. The widget must continue to advance through every prayer/jamaat boundary using only native compute, and Dart must be invoked exactly once around local midnight (verify via logcat).

## Output expectations

- Make changes file by file, smallest first. Land `WidgetState.kt` and its test before the provider rewrite so the state machine is verified in isolation.
- After each file, two-sentence summary of what changed and why.
- Final block: paste the manual-repro plan verbatim, ready for the PR description.
- Do not commit.
