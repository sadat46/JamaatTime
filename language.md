# Language Selection Implementation Plan

## Context
The Jamaat Time app currently has hardcoded Bengali + English text scattered across 20+ widgets, 12+ screens, and 14 data files (~3,400 lines of `const` Dart objects) with no i18n system. This plan adds a language selection feature (Bengali/English) using Flutter's official ARB + gen-l10n approach, covering UI labels AND all Islamic content data.

---

## Pre-Implementation Decisions (Lock Before Starting)

1. **Fallback language:** Bengali (bn) → if English translation missing, show Bengali
2. **ARB key naming convention:** `nav_`, `prayer_`, `settings_`, `countdown_`, `ebadat_`, `notification_`, `error_`, `profile_`, `sahri_iftar_`, `forbidden_`
3. **Notification language rule:** Use current app language at trigger time (reschedule all notifications on language change)
4. **Translation ownership:** Developer (solo) — no external translator workflow needed
5. **Add `generate: true`** under `flutter:` in `pubspec.yaml`

---

## Strategy: Hybrid Approach

- **UI strings** (~200 keys) → Standard ARB files via `flutter_localizations` / `gen-l10n`
- **Islamic content** (14 data files, 1000+ strings) → Bilingual model fields with locale-aware getters (keeps content co-located with its data structure, avoids unmanageable ARB files)
- **Notifications** → ARB keys accessed via a `LocaleProvider` singleton (no BuildContext available)

---

## Phase 1: Foundation (Locale Infrastructure)

### 1.1 Add dependencies
**File:** `pubspec.yaml`
- Add `flutter_localizations: { sdk: flutter }` under dependencies
- Add `generate: true` under `flutter:`

### 1.2 Create l10n config
**New file:** `l10n.yaml`
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

### 1.3 Create ARB files
**New files:** `lib/l10n/app_en.arb`, `lib/l10n/app_bn.arb`

Key prefixes: `nav_`, `prayer_`, `settings_`, `countdown_`, `ebadat_`, `notification_`, `error_`, `profile_`, `sahri_iftar_`, `forbidden_`

### 1.4 Add locale persistence to SettingsService
**File:** `lib/services/settings_service.dart`
- Add `_localeKey = 'app_locale'`
- `getLocale()` → returns saved locale or `null` (null = use system default)
- `setLocale(String?)` → persists + fires `_controller.add(null)`. Passing `null` clears saved locale (reverts to system default)

### 1.5 Create LocaleProvider singleton
**New file:** `lib/services/locale_provider.dart`
- Simple singleton with `String locale` getter/setter
- Used by services without BuildContext (NotificationService, data files)

### 1.6 Convert MyApp to StatefulWidget & wire locale
**File:** `lib/main.dart`
- `MyApp` → `StatefulWidget` listening to `SettingsService.onSettingsChanged`
- Add `locale`, `localizationsDelegates`, `supportedLocales` to MaterialApp
- **Auto-detect:** If no saved locale (`null`), omit `locale:` parameter → Flutter uses system locale matching automatically
- Update `LocaleProvider` whenever locale changes

### 1.7 iOS locale support
**File:** `ios/Runner/Info.plist`
- Add `CFBundleLocalizations` array with `bn` and `en` entries (required for iOS to recognize supported locales)

---

## Phase 2: Language Picker UI

### 2.1 Add language dropdown to settings
**File:** `lib/screens/profile_screen.dart` (line ~492, inside existing ExpansionTile)
- Add a "Language" / "ভাষা" dropdown row (same pattern as Madhab dropdown at line 493)
- Items: `সিস্টেম ডিফল্ট / System Default` (null), `বাংলা` (bn), `English` (en)
- Show native language names in dropdown
- On change: `_settingsService.setLocale(val)` → triggers MaterialApp rebuild

---

## Phase 3: Make Models Bilingual

### 3.1 WorshipGuideModel + related models
**File:** `lib/models/worship_guide_model.dart`
- `WorshipStep`: Add `titleEnglish`, `instructionEnglish`, `meaningEnglish` optional fields + locale-aware getters `getTitle(locale)`, `getInstruction(locale)`, `getMeaning(locale)`
- `WorshipGuideModel`: Already has `titleEnglish`. Add `introductionEnglish`, locale-aware getters for `conditions`, `fardActs`, `sunnahActs`, `commonMistakes`, `specialRulings`, `invalidators` (parallel English lists)
- `WorshipSection`: Add `titleEnglish`, `descriptionEnglish`, English items list
- `WorshipDua`: Add `titleEnglish`, `meaningEnglish`, `whenEnglish`
- `Reference`: Add `sourceEnglish`, `fullTextEnglish`
- `statusLabel` getter → locale-aware (ফরজ/Fard, সুন্নাত/Sunnah, মুস্তাহাব/Mustahab)

### 3.2 MonajatModel
**File:** `lib/models/monajat_model.dart`
- Add English fields for `title`, `meaning`, `context` + locale getters

### 3.3 AyatModel, DuaModel, UmrahModel
**Files:** `lib/models/ayat_model.dart`, `dua_model.dart`, `umrah_model.dart`
- Add English fields + update `fromJson` to parse them

---

## Phase 4: Add English Content to Data Files (14 files)

For each file, add `titleEnglish`, `instructionEnglish`, etc. to every constructor call:

| # | File | Content |
|---|------|---------|
| 1 | `lib/data/namaz_data.dart` | Prayer guide (largest) |
| 2 | `lib/data/wudu_data.dart` | Ablution guide |
| 3 | `lib/data/ghusl_data.dart` | Bathing guide |
| 4 | `lib/data/tayammum_data.dart` | Dry ablution |
| 5 | `lib/data/monajat_data.dart` | Supplications |
| 6 | `lib/data/tahajjud_data.dart` | Night prayer |
| 7 | `lib/data/witr_data.dart` | Witr prayer |
| 8 | `lib/data/janazah_data.dart` | Funeral prayer |
| 9 | `lib/data/qasr_data.dart` | Shortened prayer |
| 10 | `lib/data/tahiyyatul_masjid_data.dart` | Mosque greeting prayer |
| 11 | `lib/data/attahiyatu_data.dart` | Tashahhud |
| 12 | `lib/data/zakat_data.dart` | Charity guide |
| 13 | `lib/data/eman_data.dart` | Faith pillars |
| 14 | `lib/data/ramadan_roja_data.dart` | Ramadan fasting |

Also update JSON assets if any: `assets/data/ayats.json`, `duas.json`, `umrah.json`

---

## Phase 5: Replace Hardcoded UI Strings

Replace hardcoded text with `AppLocalizations.of(context).keyName` in:

| Area | Files |
|------|-------|
| Bottom nav | `lib/main.dart` (lines 94, 98, 102) |
| Home screen | `lib/screens/home_screen.dart` — prayer names, location labels, GPS messages |
| Settings | `lib/screens/profile_screen.dart` — all label text (lines 480, 496, 518, 540, 573, etc.) |
| Ebadat | `lib/screens/ebadat/ebadat_screen.dart` — tab title |
| Worship guides | `lib/screens/ebadat/topics/worship_guide_screen.dart` — share error, section headers |
| Prayer widgets | `lib/widgets/prayer_time_table.dart`, `prayer_countdown_widget.dart`, `prayer_info_card.dart` |
| Sahri/Iftar | `lib/widgets/sahri_iftar_widget.dart` |
| Forbidden times | `lib/widgets/forbidden_times_widget.dart` |
| Notifications | `lib/services/notification_service.dart` — use `LocaleProvider().locale` |
| Bookmarks | `lib/screens/bookmarks_screen.dart` |
| Admin | `lib/screens/admin_jamaat_panel.dart` |
| Ebadat widgets | `lib/widgets/ebadat/*.dart` — card titles, guide displays |

---

## Phase 6: Data Display Widgets → Use Locale Getters

Update all widgets that display data model content to use locale-aware getters:

- `worship_guide_screen.dart` → `step.getTitle(locale)` instead of `step.titleBangla`
- `ebadat_topic_card.dart` → `topic.titleEnglish` or `topic.titleBangla` per locale
- Monajat list/detail screens → `monajat.getTitle(locale)`
- Ayat/Dua/Umrah screens → locale-aware fields

---

## Implementation Order (Recommended)

1. **Phase 1** → Foundation (get gen-l10n working with ~10 test keys)
2. **Phase 2** → Language picker (so we can test switching immediately)
3. **Phase 5** → UI strings (screen by screen, starting with main.dart nav)
4. **Phase 3** → Make models bilingual
5. **Phase 4** → Add English content to data files (one file at a time)
6. **Phase 6** → Wire data display widgets to use locale getters

---

## Verification

1. Run `flutter gen-l10n` — no errors
2. Run `flutter build apk --debug` — compiles clean
3. Switch to English → all screens render without overflow, correct text
4. Switch to Bengali → all screens render correctly (existing behavior preserved)
5. Kill app & reopen → locale persists
6. Notifications show correct language text
7. Prayer countdown/calculation logic unchanged (internal keys stay English)
8. Share/copy text uses current locale
