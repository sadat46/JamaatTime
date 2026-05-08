# Home Screen Refactor Plan

## Context

`lib/screens/home_screen.dart` is 1,969 lines in a single `_HomeScreenState`. It mixes seven unrelated responsibilities — header chrome, notice-board orchestration, prayer math, jamaat fetching, notification scheduling, location loading, and home-widget syncing — and three giant methods (`_buildHomeHeader` 385 LOC, `_buildPrayerCard` 210 LOC, `build` 210 LOC). Every `setState` rebuilds the whole tree because there is no scoped state.

The goal is to split this file into focused units (~150–300 LOC each) so changes are local, rebuilds are scoped, and the code is testable. This refactor is **structural only** — no behavior changes, no new dependencies, no state-management migration. (Riverpod migration is tracked separately in `PERFORMANCE_UPGRADE_PLAN.md` Phase 3.)

---

## Target structure

```
lib/screens/home/
  home_screen.dart                  ~250 LOC  shell + lifecycle + controller wiring
  home_controller.dart              ~400 LOC  ChangeNotifier: services, timers, data state
  models/
    prayer_row_data.dart            ~70 LOC   PrayerRowType, PrayerRowData (moved from home_screen.dart:1-71)
  widgets/
    home_header.dart                ~400 LOC  _buildHomeHeader → HomeHeader widget
    notice_action_button.dart       ~110 LOC  _buildNoticeAction + notice-unread cache
    prayer_table_section.dart       ~120 LOC  prayer cards Column + tick-driven highlight
    prayer_card.dart                ~220 LOC  _buildPrayerCard → PrayerCard widget
  services/
    home_notification_scheduler.dart ~150 LOC _scheduleNotificationsIfNeeded + _buildNotificationScheduleKey
    home_widget_sync.dart           ~60 LOC   _updateHomeWidget
```

The existing `lib/screens/home_screen.dart` becomes a 5-line re-export so external imports keep working: `export 'home/home_screen.dart';`.

---

## Step-by-step

### Step 1 — Extract models (zero risk)
Move `PrayerRowType` and `PrayerRowData` (`home_screen.dart:1-71`) to `lib/screens/home/models/prayer_row_data.dart`. Add an `import` back into the new home_screen. Run `flutter analyze` — should be clean.

### Step 2 — Introduce `HomeController`
Create `lib/screens/home/home_controller.dart` as a `ChangeNotifier` that owns:
- Service instances (`SettingsService`, `LocationService`, `NotificationService`, `JamaatService`, `LocationConfigService`, `NoticeRepository`, `NoticeReadStateService`) — currently `home_screen.dart:98-104`
- Mutable state: `_now`, `selectedDate`, `isLoadingJamaat`, `_lastJamaatUpdate`, `_jamaatTimes`, location/place fields (`home_screen.dart:82-127`)
- Timer + lifecycle: `_syncHomeTimer`, `_handleHomeMinuteTick` (`home_screen.dart:680-731`)
- Async loaders: `_initializeApp`, `_fetchJamaatTimes`, `_calculateLocalJamaatTimes`, `_updatePrayerTimes`, `_loadMadhab`, `_loadBangladeshHijriOffset`, `_fetchUserLocation`, `_loadLastLocation` (`home_screen.dart:732-1300`)
- Derived data: `_computePrayerTableData`, `_getCurrentPrayerName` (`home_screen.dart:1301-1416`)

Expose state as plain getters and call `notifyListeners()` where the old code called `setState`. Keep the API minimal — methods called from widgets only (no service leakage).

`_HomeScreenState` constructs the controller in `initState`, disposes it in `dispose`, and passes it down via constructor parameters (no `InheritedWidget` yet — that's Phase 3). It also wires `WidgetsBindingObserver` and forwards `didChangeAppLifecycleState` to the controller.

### Step 3 — Extract `HomeNotificationScheduler` and `HomeWidgetSync`
Move `_scheduleNotificationsIfNeeded`, `_buildNotificationScheduleKey`, `_handleNotificationSettingsChange` (`home_screen.dart:972-1090`) to `lib/screens/home/services/home_notification_scheduler.dart` as a plain class taking the controller's prayer/jamaat data as input. Move `_updateHomeWidget` (`home_screen.dart:1417-1461`) to `home_widget_sync.dart`. The controller calls them at the same trigger points it does today.

### Step 4 — Extract `NoticeActionButton`
Move `_buildNoticeAction`, `_openNoticeBoard`, `_noticeUnreadFor`, `_resetNoticeUnreadCache` (`home_screen.dart:146-253`) to `notice_action_button.dart`. It owns its own `NoticeReadStateService` listener and unread-count `ValueNotifier` so opening the notice sheet no longer triggers a HomeScreen rebuild.

### Step 5 — Extract `PrayerCard`
Move `_buildPrayerCard` and `_localizedPrayerName` (`home_screen.dart:1462-1750`) to `prayer_card.dart` as a stateless widget taking `PrayerRowData` plus a few style/locale params. Pure function of inputs — no controller dependency. Wrap with `RepaintBoundary` per row.

### Step 6 — Extract `PrayerTableSection`
Move the prayer-cards Column build (`home_screen.dart:1897-1905`) into `prayer_table_section.dart`. It listens to the controller via `AnimatedBuilder(animation: controller, ...)` and rebuilds only when `prayerTableData` changes — uses `prevList == newList` shallow-compare to skip identical ticks.

### Step 7 — Extract `HomeHeader`
Move `_buildHomeHeader` (`home_screen.dart:254-639`), the locale helpers `_isEnglishCurrent`, `_trCurrent`, `_tr`, `_localizedDigitsForContext` (`home_screen.dart:132-145`), and `_toHijriString` (`home_screen.dart:1751-1758`) to `home_header.dart`. Header owns the city dropdown, location label, date/Hijri formatting, and embeds `NoticeActionButton`. Takes the controller for city/location reads.

### Step 8 — Slim the shell
After extractions, `lib/screens/home/home_screen.dart` is just:
- `HomeController` lifecycle (create/dispose)
- `WidgetsBindingObserver` wiring
- The outer `LayoutBuilder → Scaffold → AnnotatedRegion → RefreshIndicator → SingleChildScrollView → Column` skeleton
- Composition: `HomeHeader`, `PrayerTableSection`, `SahriIftarWidget` (already extracted), `ForbiddenTimesWidget` (already extracted)

Replace the old `lib/screens/home_screen.dart` with a one-line re-export.

### Step 9 — Add a smoke test
Create `test/screens/home_screen_smoke_test.dart` that mounts `HomeScreen` with mocked services (set via controller constructor injection — see Step 2) and verifies it renders without throwing. This guards the refactor and any future changes.

---

## Critical files

**Read-and-split:**
- `lib/screens/home_screen.dart` (1,969 LOC — source of all extractions)

**New files (created):**
- `lib/screens/home/home_screen.dart`
- `lib/screens/home/home_controller.dart`
- `lib/screens/home/models/prayer_row_data.dart`
- `lib/screens/home/widgets/home_header.dart`
- `lib/screens/home/widgets/notice_action_button.dart`
- `lib/screens/home/widgets/prayer_table_section.dart`
- `lib/screens/home/widgets/prayer_card.dart`
- `lib/screens/home/services/home_notification_scheduler.dart`
- `lib/screens/home/services/home_widget_sync.dart`
- `test/screens/home_screen_smoke_test.dart`

**Touched (re-export only):**
- `lib/screens/home_screen.dart` → `export 'home/home_screen.dart';`

**No changes:**
- `lib/widgets/sahri_iftar_widget.dart`, `lib/widgets/forbidden_times_widget.dart`, `lib/widgets/prayer_countdown_widget.dart`, `lib/widgets/live_clock_widget.dart` (already extracted; consumed by the shell unchanged)
- All `lib/services/*` files (controller wraps them, doesn't modify them)

---

## Reuse (don't re-implement)

- `LocaleDigits.localize` (`lib/utils/locale_digits.dart`) — used by header + prayer card
- `AppConstants.canttNames` (`home_screen.dart:95`) — pass to HomeHeader as a static
- `PrayerTimeEngine` (`lib/services/prayer_time_engine.dart`) — controller delegates, not duplicates
- `JamaatService.smartFetch` cache (`lib/services/jamaat_service.dart:107-193`) — controller calls it; don't add a second cache
- Existing `WidgetsBindingObserver` plumbing in `_HomeScreenState` — moves intact to the new shell

---

## Out of scope (deferred)

- Riverpod / Provider migration — see `PERFORMANCE_UPGRADE_PLAN.md` Phase 3
- Isolate-based prayer math — same
- New features, visual changes, or string changes
- Refactoring `SahriIftarWidget` / `ForbiddenTimesWidget` internals

---

## Verification

After **each step**, run:
1. `flutter analyze` — must stay clean
2. `flutter test` — must stay green
3. `flutter run` on a device — open the home screen and confirm:
   - City dropdown changes location
   - Pull-to-refresh fetches jamaat times
   - Prayer card highlight updates at the next prayer boundary
   - Notice-board badge clears after opening
   - Backgrounding then foregrounding restores correct time
   - Locale toggle (BN/EN) re-renders header + cards
4. Tail `flutter run` console — no new exceptions, no `setState() called after dispose()` errors

**Final acceptance** (after Step 9):
- `wc -l lib/screens/home/*.dart lib/screens/home/**/*.dart` — no file >450 LOC
- DevTools "Track Widget Rebuilds" on the home screen for 60 s with countdown visible — `HomeHeader` and `NoticeActionButton` rebuild counts should drop vs. baseline (rebuilds now scoped to `PrayerTableSection`)
- Smoke test passes
- Manual checklist (4) re-run end-to-end