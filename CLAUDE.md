# Jamaat Time — Codebase Guide

Flutter app: prayer times, jamaat (congregation) reminders, hijri calendar, FCM notice board, Android home widget. Audience is Bengali Muslim users; UI is bilingual EN/BN.

Package: `com.sadat.jamaattime` · Min Android: API 23 · Target: API 34 · Reference device: Samsung A52 (Android 14, multi-user — use `pm list packages --user 0`).

## Stack

Flutter 3.8+, Firebase (Auth/Firestore/Messaging/Functions/Storage/App Installations), `flutter_local_notifications`, `home_widget`, `adhan_dart`, `geolocator`, `shared_preferences`.

## Architecture map

```
lib/
├── main.dart                       app entry, Firebase bootstrap, locale init
├── core/                           cross-cutting: AppText, locale, theme, feature flags, timezone, firebase bootstrap
├── data/                           seed data assets
├── features/                       sliced features
│   ├── family_safety/              focus guard, domain blocklists, activity summary
│   └── notice_board/               FCM-driven announcements
├── l10n/                           generated localizations (EN/BN)
├── models/                         shared DTOs (LocationConfig, …)
├── screens/                        top-level screens (home/, calendar, ebadat, admin, …)
├── services/                       business services
│   └── notifications/              local + push notification subsystem (see below)
├── themes/                         Material theme tokens
├── utils/                          pure helpers
└── widgets/                        shared UI components
```

## Notification subsystem (`lib/services/notifications/`)

Most-touched area. Layout intentional — match it when adding new code.

```
notifications/
├── notification_service.dart           orchestrator (singleton, public API)
├── notification_schedule_gateway.dart  shared infra: low-level scheduling
├── notification_channel_service.dart   shared infra: channel registrar
├── notification_permission_service.dart
├── notification_localization.dart
├── notification_ids.dart               single source of truth for local IDs
├── channels/                           per-type channel defs (used only by channel service)
│   ├── prayer_channels.dart
│   ├── jamaat_channels.dart
│   └── fajr_voice_channel.dart
├── fcm/                                push (broadcast_channel + 5 fcm_* files)
└── reminders/                          three local-schedule reminder types
    ├── notification_reminder_candidate.dart   shared DTO
    ├── jamaat_reminder_scheduler.dart
    ├── jamaat_schedule_cache.dart             private to jamaat scheduler
    ├── prayer_end_reminder_scheduler.dart
    └── tahajjud_end_fajr_start_notification_scheduler.dart
```

### Notification ID space (must not collide)

| Range | Type |
|---|---|
| 1101–1105 / 1201–1205 | prayer-end today / tomorrow |
| 2101–2105 / 2201–2205 | jamaat today / tomorrow |
| 3101 / 3102 | fajr-voice today / tomorrow |

All IDs live in `notification_ids.dart`. Adding a new reminder type → new century prefix, declared in that file.

### Channel space

Per reminder type, five sound modes (0=custom, 1=system, 2=silent, 3=custom_2, 4=custom_3) → channel id like `prayer_channel_custom_2`. FCM has its own `notice_board` channel inside `fcm/broadcast_channel.dart`, deliberately distinct from reminder channels.

## Conventions

- **Editing**: prefer `Edit`/`Read` over Bash. Never read whole files when a small slice is enough.
- **New reminder type**: add scheduler under `reminders/`, channel def under `channels/`, ID range in `notification_ids.dart`, register in `NotificationService.scheduleAllNotifications` via a new `_runScheduleStep` call so failures stay isolated per reminder.
- **Localized strings**: `AppText.of(context).<key>` (EN/BN both exist). Never hardcode user-facing strings.
- **Settings**: route through `SettingsService`, not `SharedPreferences` directly.
- **Locale**: `AppLocaleController` for runtime locale; `LocalePrefs` for persisted code.
- **Comments**: only when the *why* is non-obvious (hidden invariants, workarounds). No comments that restate the code.
- **No backwards-compat shims** for unused code — delete instead.

## Gotchas / known issues

- **`SCHEDULE_EXACT_ALARM`** (Android 13+) must be granted for jamaat reminders to fire on time. Denial silently degrades to inexact. Check `notification_permission_service.dart`.
- **OEM alarm throttling** (Samsung A52, others): aggressive battery-saver kills scheduled alarms. Test on the A52 reference device.
- **Multi-user device**: `pm list packages` fails without `--user 0` on the A52.
- **Never `cancelAll` jamaat**: prior incident — wipes scheduled reminders in a race. Use targeted cancels per `NotificationIds.jamaatReminders[*]`. See commit `d19303f`.
- **Firebase keys**: rotated post Feb-2026 leak. Android Maps API key rotation still pending — do not commit any `google-services.json` containing the old key.
- **`google-services.json`** is gitignored. New machine setup: download from Firebase console.

## Build & verify

```sh
flutter analyze lib/ test/
flutter test                                    # 4 pre-existing failures unrelated to most work (notice_read_state, firebase_callable)
flutter test test/services/notifications/       # 13 tests — must stay green for any notification change
flutter build apk --debug                       # ~50s incremental, ~5min cold
flutter build apk --release                     # uses android/key.properties → keystore (do not regenerate)
```

### On-device verification

```sh
adb devices
adb -s <id> shell pm list packages --user 0 | grep jamaat
adb -s <id> shell dumpsys alarm | grep com.sadat.jamaattime     # confirms scheduled alarms armed
adb -s <id> logcat -s flutter:V JT_NOTIFY:V                     # JT_NOTIFY tag used by schedulers
```

Debug installs require uninstalling the release build first (signature mismatch). To verify without data loss: build release with the keystore.

## Red flags — stop and ask

- About to `cancelAll` any notification range.
- About to regenerate the Android release keystore (path/SHA-1 are in user memory — never replace).
- About to add a new shared singleton in `notifications/` root — most things belong under `channels/`, `fcm/`, or `reminders/` now.
- About to introduce a 4th reminder type without first checking whether a `ReminderScheduler` interface + registry is the cleaner shape than another `_runScheduleStep` call.
- About to commit anything under `android/app/google-services.json` or any file matching `*key*.properties`.

## What lives where (quick lookup)

| Need | Path |
|---|---|
| Add a localized string | `lib/core/app_text.dart` + `lib/l10n/*.arb` |
| Persist a new pref | `lib/services/settings_service.dart` |
| New screen | `lib/screens/<area>/<name>_screen.dart` |
| Tweak prayer math | `lib/services/prayer_time_engine.dart` / `prayer_aux_calculator.dart` |
| Tweak jamaat math | `lib/services/jamaat_service.dart` |
| Add a notification channel | `lib/services/notifications/channels/` + register in `NotificationChannelService.allChannelIds` |
| Add FCM payload handling | `lib/services/notifications/fcm/fcm_foreground_renderer.dart` (foreground) + `fcm_deep_link_router.dart` (taps) |
| Modify home widget | `lib/services/widget_service.dart` + `android/app/src/main/.../*Widget*.kt` |
