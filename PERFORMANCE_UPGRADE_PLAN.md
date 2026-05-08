# Performance Upgrade Plan — Jamaat Time

## Context

The app runs as a single 1,969-line `HomeScreen` StatefulWidget with no formal state management. Several timers (1s prayer countdown, 1s Sahri/Iftar countdown, 1m home tick) call `setState` on wide subtrees. A `SweepGradient.createShader()` is rebuilt every frame inside a `CustomPaint`. Heavy work (adhan_dart prayer math, Firestore `.get()`, `home_widget` batch writes, JSON asset parsing) runs on the main isolate. Startup ships two ~1 MB notification/icon PNGs and eagerly parses three Ebadat JSON files. Result: visible jank on the home screen during countdowns, stutter on minute boundaries, and slower-than-needed cold start.

This plan covers all three layers (jank, startup/assets, state-management + isolates) and is sequenced so each phase is independently shippable.

---

## Phase 1 — Surgical jank fixes (highest ROI, no architecture change)

1. **Cache the sweep-gradient shader.**
   - `lib/widgets/prayer_countdown_widget.dart:408-415` → store the shader in `_CircularProgressPainter` and only recreate when `size` or color list changes; override `shouldRepaint` to compare those inputs.

2. **Stop rebuilding the whole countdown every second.**
   - `lib/widgets/prayer_countdown_widget.dart:90-94, 200-206` → replace `Timer.periodic` + `setState` with a `ValueNotifier<CountdownTick>` driven by the timer. Wrap only the `CustomPaint` and the time `Text` in `ValueListenableBuilder`. Wrap with `RepaintBoundary`.
   - Same pattern for `lib/widgets/sahri_iftar_widget.dart:268-273` (Sahri/Iftar 1s timer).

3. **Hoist `DateFormat` and digit-localization out of `build()`.**
   - `lib/widgets/prayer_countdown_widget.dart:152, 160`, `lib/screens/home_screen.dart:1345, 1543-1545`, `lib/widgets/forbidden_times_widget.dart:411` → store `DateFormat` instances as `late final` fields or memoize per-locale in a small util. Reuse existing `lib/utils/locale_digits.dart` but cache its result per (digits, locale) via a tiny `Map` cache.

4. **Memoize HomeScreen theme/color computation.**
   - `lib/screens/home_screen.dart:1770-1782` → compute dark-mode colors and padding breakpoints in `didChangeDependencies` (or via a small `_HomeStyle` value object) instead of every `build`.

5. **Pause animations when not visible.**
   - `lib/widgets/sahri_iftar_widget.dart:797-804` and `lib/widgets/forbidden_times_widget.dart:153-159` → use `TickerMode` / `VisibilityDetector` (or `WidgetsBindingObserver` lifecycle hook already present) to `stop()` the pulse `AnimationController` when the route is backgrounded.

6. **Add `RepaintBoundary` around expensive subtrees.**
   - Around the countdown `CustomPaint`, around each prayer card row in `home_screen.dart:1897-1905`, and around the Sahri/Iftar fullscreen page.

7. **Add `const` constructors** to leaf widgets in `home_screen.dart` (icons, dividers, labels) — quick mechanical pass.

---

## Phase 2 — Startup and asset cleanup

8. **Compress oversized PNGs.** (use a local image tool — not committed via Claude)
   - `assets/icon/family_safety.png` (1.1 MB) and `assets/icon/ic_notification_jamaat_time_white.png` (1.0 MB) → re-export at correct mdpi/xxhdpi sizes, PNG-quantize. Target <80 KB each.

9. **Lazy-load Ebadat JSON.**
   - `lib/services/ebadat_data_service.dart:30-103` → don't parse on startup. Parse on first access from each tab; wrap in `compute()` so JSON decode runs off the main isolate.

10. **Batch notification channel creation.**
    - `lib/services/notification_service.dart:427-468` → defer non-critical channels until first schedule of that channel; keep only Fajr + general channels at boot.

11. **Precache critical images / fonts after first frame.**
    - In the existing `addPostFrameCallback` block in `lib/main.dart:55-91`, add `precacheImage` for the home header icon and notification icons; ensure `GoogleFonts.pendingFonts()` (line 101) only awaits the in-use locale's fonts.

---

## Phase 3 — State management + isolates

12. **Introduce Riverpod.** (chosen over Provider for `select`/family ergonomics; lighter than BLoC.)
    - Add `flutter_riverpod` to `pubspec.yaml`. Wrap `runApp` in `ProviderScope` in `lib/main.dart`.
    - New providers under `lib/state/`:
      - `locationProvider` (wraps `lib/services/location_service.dart`)
      - `prayerTimesProvider` (family keyed by date+coords+method, computed in isolate)
      - `jamaatTimesProvider` (wraps `lib/services/jamaat_service.dart`)
      - `settingsProvider`, `localeProvider` (replace `AppLocaleController`)
      - `currentMinuteProvider` (single global 1-minute ticker — replaces per-widget `Timer.periodic(1m)`)
      - `currentSecondProvider` (single 1-second ticker for countdowns)
    - HomeScreen children read via `ref.watch(provider.select(...))` so only the dependent slice rebuilds.

13. **Break up `HomeScreen` (`lib/screens/home_screen.dart`, 1,969 lines).**
    - Split into: `HomeHeader`, `PrayerTableSection`, `SahriIftarSection`, `ForbiddenTimesSection`, `NoticeBoardSection` — each as a `ConsumerWidget` reading only the providers it needs. Target <300 lines per file.

14. **Move prayer-time math to an isolate.**
    - `lib/services/prayer_time_engine.dart:113-124` → wrap `PrayerTimes(...)` construction in `Isolate.run` (Dart 3+) or `compute()`. Cache results by `(date, lat, lng, method, madhab)` key — invalidate on coord/method change only. Tomorrow's Fajr (`home_screen.dart:1441-1449`) reads from same cache.

15. **Move Firestore + JSON I/O off main isolate.**
    - `lib/services/jamaat_service.dart:107-193` → keep network on main isolate (Firestore SDK requires it) but parse the response in `compute()`.
    - `lib/services/widget_service.dart:219-374` → batch the 30+ `HomeWidget.saveWidgetData` calls into a single platform-channel write (add a `saveWidgetDataMap` method on the Android side) to cut the round-trip count.

---

## Critical files

- `lib/main.dart`
- `lib/screens/home_screen.dart` (split required)
- `lib/widgets/prayer_countdown_widget.dart`
- `lib/widgets/sahri_iftar_widget.dart`
- `lib/widgets/forbidden_times_widget.dart`
- `lib/widgets/live_clock_widget.dart`
- `lib/services/prayer_time_engine.dart`
- `lib/services/jamaat_service.dart`
- `lib/services/notification_service.dart`
- `lib/services/widget_service.dart`
- `lib/services/ebadat_data_service.dart`
- `lib/utils/locale_digits.dart`
- `assets/icon/family_safety.png`, `assets/icon/ic_notification_jamaat_time_white.png`
- `pubspec.yaml` (add `flutter_riverpod`)
- `android/app/src/main/kotlin/.../WidgetPlugin.kt` (batch saveWidgetData) — verify path before editing

---

## Verification

Run each phase in profile mode (`flutter run --profile`) and capture before/after:

1. **Cold start** — `adb shell am start -W -n com.shadat.jamaat_time/.MainActivity` → record `TotalTime`. Target: −20% after Phase 2.
2. **Frame timings** — DevTools Performance overlay on home screen with countdown visible for 60 s. Target: zero raster jank, build phase <8 ms after Phase 1.
3. **Scroll jank** — scroll the Ebadat list and Calendar screen with Performance overlay; record dropped-frame %.
4. **Prayer-tick boundary** — wait for a prayer minute boundary; confirm no visible stutter (check timeline: `_handleHomeMinuteTick` should no longer cascade-rebuild after Phase 3).
5. **Memory** — DevTools Memory tab; confirm no leaked tickers when switching tabs (Phase 1 step 5).
6. **Manual smoke** — Fajr notification still fires, jamaat times still load, widget still updates, locale switch still works (Phase 3 ProviderScope refactor).
7. **APK size** — `flutter build apk --release --analyze-size` before/after Phase 2 image compression.
