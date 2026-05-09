# Performance Upgrade Plan — Jamaat Time

## Current state (May 2026)

The home-screen structural refactor has shipped. `lib/screens/home_screen.dart` is now a one-line re-export to `lib/screens/home/home_screen.dart` (~190 LOC shell). State is owned by `HomeController` (`lib/screens/home/home_controller.dart`, `ChangeNotifier`). Presentation is split into `home/widgets/home_header.dart`, `prayer_table_section.dart`, `prayer_card.dart`, and `notice_action_button.dart`. Per-section rebuilds are scoped via `AnimatedBuilder(animation: controller, ...)` with shallow-compare on the prayer-table list.

What still bites: a `SweepGradient.createShader()` rebuilt every frame in the countdown painter, three relevant `Timer.periodic(1s)` widget timers (prayer countdown plus the inline and fullscreen Sahri/Iftar countdowns), three long-lived `Timer.periodic(1m)` timers in the live clock, forbidden-times widget, and `HomeController`, `setState` cascades on those tickers, prayer-time math (`adhan_dart`) on the main isolate, unverified first-access JSON parsing in `EbadatDataService`, and oversized image resources that need packaging verification. `android/app/src/main/res/drawable/ic_notification.png` is confirmed APK-packaged; `assets/icon/` files may be source-only unless build analysis proves otherwise.

This plan is split into three independently shippable phases. **Sequencing is load-bearing**: Phase 1 is leaf-widget jank fixes that touch nothing structural; Phase 2 is startup/asset cleanup; Phase 3 introduces a *narrow* Riverpod surface (global tickers + an isolate-backed prayer-times provider) without rewriting `HomeController` and without migrating every screen. Riverpod arrives only where it pays for itself.

---

## Sequencing principle

`HomeController` is recently shipped, well-tested, and load-bearing. We do not replace it. We add Riverpod in Phase 3 *only* for the cross-cutting concerns where it's clearly the right tool: a single global tick source for the long-lived widget/controller timers and a memoized, isolate-backed prayer-times provider. Other screens' state management stays where it is until a feature reason forces a touch.

```
Phase 1 (leaf widgets)  ─┐
                         ├─►  ship in any order, all reversible per-file
Phase 2 (startup/assets)─┘
                              │
                              ▼
                     Phase 3 (tickers + isolate)
                     blocked by: nothing in Phase 1/2 needs to be done first,
                                 but ship Phase 1 first so jank wins are
                                 attributable to leaf-widget work, not state mgmt.
```

---

## Phase 1 — Jank fixes (leaf widgets, no architecture change)

**Goal.** Eliminate visible stutter on the countdown, sahri/iftar, and forbidden-times widgets. Drive the home-screen build phase under 8 ms with a 1-second countdown visible.

**Exit criteria.**
- DevTools "Track Widget Rebuilds" on home: only the countdown numerals and the live clock rebuild once per second; nothing rebuilds once per frame.
- DevTools Performance overlay: zero raster jank for 60 s with countdown visible; build phase median <8 ms.
- `flutter analyze` clean; `flutter test` green.

### 1.1 Cache the sweep-gradient shader
**Where:** `lib/widgets/prayer_countdown_widget.dart` → `_CircularProgressPainter.paint`.
**What:** cache the `Shader` by `Rect`, `startColor`, `endColor`, and sweep-angle bucket; rebuild it only when one of those inputs changes. Tighten `shouldRepaint` to compare only the visual inputs that can change the ring.
**Why:** `gradient.createShader(rect)` runs every paint. With a 1 s tick and a `RepaintBoundary` upstream the shader is the dominant per-paint cost.
**Acceptance:** in DevTools timeline, `_CircularProgressPainter.paint` self-time drops; identical-second frames show `shouldRepaint == false`.

### 1.2 Drive countdowns with `ValueNotifier` + `ValueListenableBuilder`
**Where:**
- `lib/widgets/prayer_countdown_widget.dart` (`Timer.periodic` at line ~90)
- `lib/widgets/sahri_iftar_widget.dart` (two `Timer.periodic` instances around lines 268 and 808)

**What:** keep the local timer source for Phase 1, but replace tick-driven `setState` calls with a `ValueNotifier<CountdownTick>` driven by the timer. Wrap only the `CustomPaint` and the time `Text` in `ValueListenableBuilder`. Wrap each expensive paint subtree in a `RepaintBoundary`. Full timer consolidation is deferred to Phase 3.
**Acceptance:** the parent `State` rebuilds zero times per second on Track Widget Rebuilds — only the inner `ValueListenableBuilder` subtrees fire.

### 1.3 Hoist `DateFormat` and digit localization out of `build`
**Where:**
- `lib/widgets/prayer_countdown_widget.dart`
- `lib/widgets/forbidden_times_widget.dart`
- `lib/screens/home/widgets/home_header.dart`
- `lib/screens/home/widgets/prayer_card.dart`

**What:** cache `DateFormat` instances as `late final` fields per widget, or memoize per-locale via a small shared cache such as `lib/utils/date_format_cache.dart`. Keep digit localization separate; only move it out of tick-driven rebuild paths where the input text is unchanged.
**Acceptance:** allocator profile in DevTools shows no `DateFormat` allocation per tick.

### 1.4 Memoize home theme/style computation
**Where:** `lib/screens/home/widgets/home_header.dart` and any style helpers used by `prayer_card.dart` / `home_screen.dart` shell.
**What:** compute dark-mode colors and breakpoint-derived padding in `didChangeDependencies` (or via a `_HomeStyle` value object stored on `State`), not in `build`.

### 1.5 Pause animations when route is backgrounded
**Where:** `lib/widgets/sahri_iftar_widget.dart`, `lib/widgets/forbidden_times_widget.dart`.
**What:** gate the pulse `AnimationController` on `TickerMode.of(context)`; stop on `AppLifecycleState.paused`. The `WidgetsBindingObserver` plumbing is already in place via the home shell — extend it down or read `TickerMode` directly.
**Acceptance:** no ticker callbacks fire while the app is backgrounded (verify via a debug log + a 30 s background hold).

### 1.6 Add `RepaintBoundary` around expensive subtrees
**Where:**
- around the countdown `CustomPaint` (1.2 already adds this)
- around each `PrayerCard` in `lib/screens/home/widgets/prayer_table_section.dart`
- around the Sahri/Iftar fullscreen page

### 1.7 `const` constructors on leaf widgets
Mechanical pass over `lib/screens/home/widgets/*.dart` and the affected leaf widgets touched in 1.1–1.6.

**Risk / rollback.** Each change is local to one widget; revert per-file with `git revert`. The `ValueNotifier` swap (1.2) is the only step with a behavioral surface — gate by `flutter test` and a manual minute-boundary smoke (wait for the next prayer change and verify the highlight moves).

---

## Phase 2 — Startup and asset cleanup

**Goal.** Cut cold-start time and reduce APK size. No behavioral changes.

**Exit criteria.**
- `adb shell am start -W -n com.sadat.jamaattime/.MainActivity` `TotalTime` is recorded before/after on the same mid-range Android device; target a measurable reduction from notification-channel deferral and font-preload trimming.
- Release-mode APK size shrinks by the reduction in confirmed packaged native image resources. Do not count source-only `assets/icon/` files unless `flutter build apk --release --analyze-size` proves they are packaged.
- DevTools/profile-mode startup trace shows no Ebadat JSON parsing during cold start; first Ebadat tab open is profiled separately.

**Implementation status (May 2026).**
- 2.1: packaged `android/app/src/main/res/drawable/ic_notification.png` re-exported from 1254x1254 / 1,029,132 bytes to a transparent 96x96 / 2,280-byte Android notification glyph. Matching source counterpart `assets/icon/ic_notification_jamaat_time_white.png` was updated to the same size. `assets/icon/family_saFETY.png` is not declared in `pubspec.yaml` and has no code references, so it remains source-only and is not counted as an APK-size win. Samsung A52 notification-shade smoke passed with no square fill.
- 2.2: call-site audit passed. `EbadatDataService` loaders are reached from Ebadat/bookmark screens, not from `main()` or the home cold-start path. Keep direct parsing while the three JSON files remain about 50 KB total.
- 2.3: implemented. Android boot creates only the active prayer channel, active jamaat channel, and Fajr voice channel; other sound-mode channels are created lazily before scheduling.
- 2.4: implemented in `lib/main.dart`. Font preload runs after first frame and only touches the active locale's text theme. No Flutter image precache was added because no confirmed critical first-frame `Image.asset` was found.
- Verification: `flutter build apk --release --analyze-size --target-platform android-arm64` completed and produced a 23.9 MB release APK. Samsung A52 ADB cold-start check on the currently installed package reported `TotalTime` median 5370 ms across five cold launches; the freshly built APK could not be installed over that package because the device install has a different signing certificate. An ADB method trace was captured; Flutter `--profile --trace-startup` remained blocked by the local Flutter tool hang.

### 2.1 Compress packaged oversized image resources *(manual; verify packaging first)*
**Where:** confirmed APK-packaged target: `android/app/src/main/res/drawable/ic_notification.png` (~1.0 MB). Source candidates to verify before counting toward APK size: `assets/icon/ic_notification_jamaat_time_white.png` (~1.0 MB) and `assets/icon/family_saFETY.png` (~1.1 MB).
**What:** re-export the packaged native notification icon at the correct Android notification-icon dimensions and PNG-quantize it. If source PNGs regenerate native resources, compress the source counterparts too; otherwise treat source-only compression as repo-size cleanup, not APK-size work.
**Acceptance:** release APK/analyze-size output shows the packaged resource reduction; notification icon rendering is unchanged on device. `assets/icon/` file sizes are reported separately and are not used as APK-size proof unless packaging is confirmed.

### 2.2 Confirm lazy-load and profile Ebadat JSON
**Where:** `lib/services/ebadat_data_service.dart` (`loadAyats`, `loadDuas`, `loadUmrahSections`).
**What:** the in-memory cache is already there — good. Confirm none of these loaders are called during `main()` / `initState` of the home shell (audit call sites: `bookmarks_screen.dart`, `screens/ebadat/tabs/*.dart`). The three JSON assets are currently about 50 KB total, so keep direct `json.decode(...)` unless DevTools shows a real first-tab-open main-isolate stall. Add `compute()` only if profiling proves it helps.
**Acceptance:** profile-mode timeline shows no Ebadat JSON decode during cold start. First Ayat/Dua/Umrah tab open shows no visible frame jank from JSON parsing; if it does, add an isolate parse and re-measure.

### 2.3 Defer non-critical notification channels
**Where:** `lib/services/notification_service.dart` (channel-creation block, currently around lines 427–468 — verify before editing).
**What:** at boot, create only the active prayer channel for the user's current prayer sound mode, the active jamaat channel for the user's current jamaat sound mode, and the Fajr voice channel. Defer all other sound-mode channels until first schedule of that channel or until the user changes notification sound mode.
**Acceptance:** cold-start timeline shows fewer platform-channel calls during `notificationService.initialize`.

### 2.4 Trim font preload and precache only real Flutter assets
**Where:** `lib/main.dart` `addPostFrameCallback` block (currently ~lines 55–91).
**What:** ensure `GoogleFonts.pendingFonts(...)` only awaits the in-use locale's fonts. Add `precacheImage` only for confirmed critical Flutter `Image.asset` / `AssetImage` usage. Do not precache native notification resources through Flutter; notification icons live in Android resources, not the Flutter asset cache.
**Acceptance:** font preload is limited to the active locale, any confirmed Flutter image precache has a real call site, and cold-start measurements improve or at least do not regress.

**Risk / rollback.** All Phase 2 code changes are reversible with a single revert. Image compression is the only non-code change; keep originals in a `tools/originals/` folder (gitignored) for the first release. Do not claim APK-size wins from source-only assets.

---

## Phase 3 — Targeted state extraction (Riverpod, narrow surface)

**Goal.** Replace the long-lived widget/controller tickers with a single global tick source, and move prayer-time math off the main isolate, *without* rewriting `HomeController` or migrating other screens.

**Why narrow.** The home refactor just shipped a clean `HomeController` seam with scoped rebuilds. A wholesale Riverpod migration would throw that away for no behavior win. We add Riverpod *only* where it's strictly better than the alternative: cross-cutting tick sources and a cache+isolate boundary for prayer math. Everything else stays on `ChangeNotifier` until a feature touches it.

**Exit criteria.**
- `git grep "Timer.periodic" lib/widgets lib/screens` returns zero matches in long-lived home-related widget files after 3.4. One match is acceptable inside `currentMinuteProvider` / `currentSecondProvider`; the short-lived `lib/widgets/focus_guard/munajat_disable_dialog.dart` timer remains intentionally out of scope.
- `PrayerTimes(...)` construction runs in a worker isolate via `compute()`; results are cached by `(date, lat, lng, method, madhab)` and reused by today's-and-tomorrow's-Fajr lookups.
- DevTools timeline shows no main-isolate stall at the prayer-minute boundary.
- `test/screens/home_screen_smoke_test.dart` still passes; `flutter analyze` clean.

### 3.1 Add `flutter_riverpod` and wrap `runApp` in `ProviderScope`
**Where:** `pubspec.yaml`, `lib/main.dart`.
**What:** add `flutter_riverpod: ^2.5.0` (verify latest 2.x). Wrap the existing `runApp(MyApp(...))` in `ProviderScope`. No other code change in this step.
**Acceptance:** the app launches with byte-identical behavior; the smoke test passes; `flutter analyze` clean. This is purely the prerequisite step.

### 3.2 Build the global ticker providers
**Where:** new file `lib/state/tick_providers.dart`.
**What:**
- `currentSecondProvider` — `StreamProvider<DateTime>` emitting at each wall-clock second boundary (align to `now.millisecondsSinceEpoch % 1000`, do not use `now + Duration(seconds: 1)`).
- `currentMinuteProvider` — same for minute boundaries.

Both providers must dispose their underlying timer when unwatched (`ref.onDispose`). Add a unit test: subscribe, verify cadence, unsubscribe, verify the timer is cancelled.
**Acceptance:** unit test passes; manually verify by listening in a debug widget that the first emission lands within ≤50 ms of the next wall-clock second.

### 3.3 Migrate widget-level tickers
Convert these to `ConsumerStatefulWidget` (or `ConsumerWidget`), replacing their internal `Timer.periodic` with `ref.watch`:
- `lib/widgets/prayer_countdown_widget.dart` — 1 s tick (already on `ValueNotifier` after 1.2; replace the timer source with `currentSecondProvider`)
- `lib/widgets/sahri_iftar_widget.dart` — both 1 s timers
- `lib/widgets/live_clock_widget.dart` — 1 m tick
- `lib/widgets/forbidden_times_widget.dart` — 1 m tick

Leave `lib/widgets/focus_guard/munajat_disable_dialog.dart` alone — it's a short-lived dialog with its own lifecycle; not worth the surface-area change.

`HomeController._timer` (the 1 m tick at `home_controller.dart:590`) is **deferred** to 3.4 — see below.

**Acceptance:** each migrated widget's `Timer.periodic` is gone; the widget rebuilds only on `ref.watch` emit.

### 3.4 Bridge `HomeController` to `currentMinuteProvider`
**Where:** `lib/screens/home/home_screen.dart` (the shell), `lib/screens/home/home_controller.dart`.
**What:** the shell becomes a `ConsumerStatefulWidget`. It watches `currentMinuteProvider` and forwards each tick to `controller.onMinuteTick(now)` (a thin renamed wrapper around the existing `_handleHomeMinuteTick`). The controller's internal `_timer` is removed; the `Timer.periodic(1m)` becomes a no-op the controller no longer owns.

This keeps `HomeController` a pure `ChangeNotifier` with no Riverpod dependency — the shell does the bridging. Easier to test in isolation, and the controller stays usable in non-Riverpod contexts.
**Acceptance:** `HomeController` no longer constructs a `Timer`; minute-boundary highlight still moves; smoke test still passes.

### 3.5 Isolate-backed prayer-times provider
**Where:** new file `lib/state/prayer_times_provider.dart`; `lib/services/prayer_time_engine.dart`; `lib/screens/home/home_controller.dart`.
**What:**
- Define a value-typed key: `class PrayerTimesKey { final DateTime date; final double lat, lng; final String method, madhab; ... }` with proper `==`/`hashCode`.
- In `prayer_time_engine.dart`, extract a top-level function `_computePrayerTimesIsolate(PrayerTimesKey key) -> Map<String, DateTime?>` that runs the existing `PrayerTimes(...)` construction and returns a primitive map (do not send `adhan_dart` types across the isolate boundary — they may not be `Sendable`-safe; round-trip primitives only).
- `prayerTimesProvider` — `FutureProvider.family<Map<String, DateTime?>, PrayerTimesKey>` that calls `compute(_computePrayerTimesIsolate, key)`. In-memory memoization via the family's auto-disposal config (or a small LRU on top); cache invalidates when coords or method change naturally because the key changes.
- In `HomeController`, replace direct `PrayerTimes(...)` construction in `initialize` and `_updatePrayerTimes` with a read from the provider. Inject access via a thin `PrayerTimesGateway` interface (constructor-injected; default impl reads `ref`, test impl returns a fixture). Keeps the controller ref-free for unit tests.

**Acceptance:** profile-mode timeline at the prayer-recompute boundary shows the CPU spike on a worker isolate; main-isolate stall ≤2 ms; tomorrow's-Fajr read is a cache hit (verified by a debug counter or a logged "cache miss" the second time).

### 3.6 Off-main-isolate JSON parsing for jamaat fetch
**Where:** `lib/services/jamaat_service.dart` — the parsing inside `smartFetch` (and any other code path that decodes the Firestore response into the in-memory shape).
**What:** keep network on the main isolate (Firestore SDK requires it). Wrap the JSON-shape-to-`Map` conversion in `compute()`.
This step is **independent of Riverpod** — it can ship before or after 3.1 if useful.

### 3.7 Batch home-widget writes
**Where:** `lib/services/widget_service.dart` (the 30+ `HomeWidget.saveWidgetData` calls in the sync method) and `android/app/src/main/kotlin/.../WidgetPlugin.kt` (verify path before editing).
**What:** add a `saveWidgetDataMap(Map<String, Object?>)` method on the Android side; collapse the per-key calls into one platform-channel round-trip per sync.
**Acceptance:** DevTools timeline shows one platform-channel call per widget sync, not 30+.
**Rollback:** gate behind a feature flag; keep the unbatched path for one release.

**Out of scope for Phase 3 (deferred indefinitely).**
- Replacing `HomeController` with Riverpod providers. The controller is the seam we just built.
- Migrating `AppLocaleController`, `SettingsService`, `LocationService`, `JamaatService` to providers. Touch them when a feature forces it.
- Splitting `HomeScreen` children into `ConsumerWidget`s — already split during the home refactor.
- A `currentSecondProvider`-driven `live_clock_widget` is in scope; a global `tickerScheduler` abstraction is not.

**Risk / rollback for Phase 3.**
- 3.1 `ProviderScope`: behaviorally inert; revert by removing the wrapper.
- 3.2/3.3 tickers: drift risk if implementation uses `now + Duration(seconds: 1)` instead of wall-clock alignment. Mitigation: enforce alignment in the provider; add the unit test in 3.2. Roll back per-widget if a regression appears.
- 3.4 controller bridge: if `_handleHomeMinuteTick` had subtle ordering with the old timer, the bridged version may differ. Mitigation: preserve the call signature; A/B test the minute-boundary highlight against a baseline build.
- 3.5 isolate prayer math: send-port serialization risk on `adhan_dart` types — already mitigated by sending only primitives. Latency risk on first paint: render the previous-known prayer times until the future resolves; pre-warm in `HomeController.initialize` so the first frame after launch is a cache hit.
- 3.7 batched write: Android-side risk; behind feature flag for one release.

---

## Verification matrix

Run all measurements in **profile mode** (`flutter run --profile`) on the same device with the same locale and the same time-of-day window each time.

| # | Metric | Tool / command | Baseline (capture before Phase 1) | Target |
|---|---|---|---|---|
| 1 | Cold start | `adb shell am start -W -n com.sadat.jamaattime/.MainActivity` → `TotalTime` | _fill in_ | measurable reduction after Phase 2 |
| 2 | Build phase, home | DevTools Performance overlay, 60 s with countdown visible | _fill in_ | median <8 ms after Phase 1 |
| 3 | Raster jank, home | DevTools Performance, dropped-frame % | _fill in_ | 0% after Phase 1 |
| 4 | Ebadat first-tab decode | DevTools profile timeline while opening Ayat/Dua/Umrah tabs | _fill in_ | no cold-start decode; no visible first-tab jank |
| 5 | Prayer-tick boundary | Wait for next prayer change; inspect timeline | _fill in_ | no main-isolate stall after Phase 3 |
| 6 | Memory, tab switching | DevTools Memory tab; switch tabs 20×, GC | _fill in_ | no leaked tickers (baseline-stable) |
| 7 | APK size | `flutter build apk --release --analyze-size` | _fill in_ | reduced by confirmed packaged native image savings |

**Manual smoke (run after every phase):**
- Fajr notification fires.
- Jamaat times load on cold start and on pull-to-refresh.
- Home widget updates on settings change.
- Locale toggle (BN / EN) re-renders header and cards correctly.
- Backgrounding for 30 s then foregrounding restores the correct current-prayer highlight.

---

## Critical files

The list below is descriptive, not prescriptive — actual touched files per step are listed inside each step.

- `lib/main.dart`
- `lib/screens/home/home_screen.dart` (shell)
- `lib/screens/home/home_controller.dart`
- `lib/screens/home/widgets/home_header.dart`, `prayer_table_section.dart`, `prayer_card.dart`, `notice_action_button.dart`
- `lib/widgets/prayer_countdown_widget.dart`, `sahri_iftar_widget.dart`, `forbidden_times_widget.dart`, `live_clock_widget.dart`
- `lib/services/prayer_time_engine.dart`, `jamaat_service.dart`, `notification_service.dart`, `widget_service.dart`, `ebadat_data_service.dart`
- `lib/utils/locale_digits.dart`
- `lib/state/tick_providers.dart` *(new, Phase 3)*, `lib/state/prayer_times_provider.dart` *(new, Phase 3)*
- `android/app/src/main/res/drawable/ic_notification.png`
- `assets/icon/family_saFETY.png`, `assets/icon/ic_notification_jamaat_time_white.png` *(source candidates; verify packaging before counting APK impact)*
- `pubspec.yaml` (Phase 3 adds `flutter_riverpod`)
- `android/app/src/main/kotlin/.../WidgetPlugin.kt` (Phase 3.7) — verify path before editing

---

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `ValueNotifier` swap (1.2) regresses tick correctness | Low | Medium | Smoke test minute boundary; per-file revert |
| Packaged image re-export (2.1) introduces visual regression | Low | Low | Diff visually on notification rendering before commit |
| Unnecessary `compute()` JSON parse (2.2) slows first-tab open | Medium | Low | Keep direct parse unless DevTools shows a real stall |
| Riverpod ticker drift (3.2) | Medium | Medium | Wall-clock alignment + unit test |
| `adhan_dart` types not isolate-safe (3.5) | Medium | High | Round-trip primitives only; pre-warm cache in `initialize` |
| Batched widget write (3.7) breaks one widget variant | Medium | Medium | Feature flag for one release |

---

## Out of scope

- Replacing `HomeController`.
- Riverpod migration for screens beyond the home stack.
- New features, visual changes, or copy changes.
- Refactors of `SahriIftarWidget` / `ForbiddenTimesWidget` internals beyond what Phase 1/3 explicitly touch.
- iOS-side widget batching (Android only — iOS uses a different code path).
