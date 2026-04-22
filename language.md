# Language Selection Implementation Plan

## Context
The Jamaat Time app currently has hardcoded Bengali + English text scattered across 20+ widgets, 12+ screens, and 14 data files (~3,400 lines of `const` Dart objects) with no i18n system. This plan adds a language selection feature (Bengali/English) using Flutter's official ARB + gen-l10n approach, covering UI labels AND all Islamic content data.

---

## Pre-Implementation Decisions (Lock Before Starting)

1. **Template & fallback:** `app_en.arb` is the template (defines all keys; English is the gen-l10n fallback). Bengali is the **runtime default** — `MaterialApp(locale: Locale('bn'))` when no user preference is saved. This means Bengali users see Bengali out of the box; if a Bengali key is ever missing, English kicks in as the ultimate fallback.
2. **ARB key naming convention:** `nav_`, `prayer_`, `settings_`, `countdown_`, `ebadat_`, `notification_`, `error_`, `profile_`, `sahri_iftar_`, `forbidden_`
3. **Notification language rule:** Use current locale from `LocaleProvider` at **schedule time** (title/body are baked in when `scheduleNotification()` is called). On language change, cancel and reschedule all pending notifications with the new locale's strings.
4. **Translation ownership:** Developer (solo) — no external translator workflow needed
5. **Add `generate: true`** under `flutter:` in `pubspec.yaml`

---

## Strategy: Hybrid Approach

- **UI strings** (~200 keys) → Standard ARB files via `flutter_localizations` / `gen-l10n`
- **Islamic content** (14 data files, 1000+ strings) → Bilingual model fields with locale-aware getters (keeps content co-located with its data structure, avoids unmanageable ARB files)
- **Notifications** → ARB keys accessed via a `LocaleProvider` singleton (no BuildContext available); strings resolved at schedule time

---

## Phase 1: Foundation (Locale Infrastructure)

### 1.1 Add dependencies
**File:** `pubspec.yaml`
- Add `flutter_localizations: { sdk: flutter }` under dependencies
- Add `generate: true` under `flutter:` (note: existing `generate: true` entries at lines 123/128/132 are under `flutter_launcher_icons:`, which is unrelated)

### 1.2 Create l10n config
**New file:** `l10n.yaml`
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

Note: `template-arb-file: app_en.arb` means English defines all keys and is the gen-l10n fallback. Bengali is the runtime default via MaterialApp's `locale` parameter (see 1.6).

### 1.3 Create ARB files
**New files:** `lib/l10n/app_en.arb`, `lib/l10n/app_bn.arb`

Key prefixes: `nav_`, `prayer_`, `settings_`, `countdown_`, `ebadat_`, `notification_`, `error_`, `profile_`, `sahri_iftar_`, `forbidden_`

Start with ~10 test keys to validate the pipeline, then expand in Phase 5.

### 1.4 Add locale persistence to SettingsService
**File:** `lib/services/settings_service.dart`
- Add `_localeKey = 'app_locale'`
- `getLocale()` → returns saved locale or `null` (null = Bengali default)
- `setLocale(String?)` → persists + fires `_controller.add(null)`. Passing `null` clears saved locale (reverts to Bengali default)
- Follows existing pattern used by `_madhabKey`, `_themeKey`, etc. with the `_controller` broadcast stream

### 1.5 Create LocaleProvider singleton
**New file:** `lib/services/locale_provider.dart`
- Simple singleton with `String locale` getter/setter (defaults to `'bn'`)
- Used by services without BuildContext: `NotificationService` (at schedule time), `WidgetService` (for home widget labels), data files

### 1.6 Convert MyApp to StatefulWidget & wire locale
**File:** `lib/main.dart`
- `MyApp` at line 61 is currently `StatelessWidget` → convert to `StatefulWidget`
- Subscribe to `SettingsService().onSettingsChanged` in `initState`
- Add to `MaterialApp`:
  - `locale`: read from SettingsService; if null, use `Locale('bn')` (Bengali default)
  - `localizationsDelegates`: `[AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate]`
  - `supportedLocales`: `[Locale('bn'), Locale('en')]`
- Update `LocaleProvider` whenever locale changes

### 1.7 iOS locale support
**File:** `ios/Runner/Info.plist`
- Add `CFBundleLocalizations` array with `bn` and `en` entries (required for iOS to recognize supported locales)

---

## Phase 2: Language Picker UI

### 2.1 Add language dropdown to settings
**File:** `lib/screens/settings_screen.dart` (insert after line 300, after the "Prayer Calculation" section card closes, before "Notifications" section at line 303)

Use the existing `_buildSectionCard` (line 133) and `_buildDropdownField` (line 195) patterns already in this file:

- Add a new `_buildSectionCard` with `icon: Icons.language`, `title: 'Language'` / `'ভাষা'`
- Inside, use `_buildDropdownField<String?>` with items:
  - `null` → `'বাংলা (Default)'`
  - `'en'` → `'English'`
  - `'bn'` → `'বাংলা'`
- Add `String? _locale` state variable, load in `_loadSettings()` via `_settingsService.getLocale()`
- On change: `_settingsService.setLocale(val)` → triggers MaterialApp rebuild via `onSettingsChanged` stream

---

## Phase 3: Make Models Bilingual

### 3.1 WorshipGuideModel + related models
**File:** `lib/models/worship_guide_model.dart`

**Already exists (no changes needed):**
- `WorshipGuideModel.titleEnglish` (line 64)

**Add English fields + locale-aware getters:**
- `WorshipGuideModel`: Add `introductionEnglish`, `conditionsEnglish`, `fardActsEnglish`, `sunnahActsEnglish`, `commonMistakesEnglish`, `specialRulingsEnglish`, `invalidatorsEnglish` (all optional) + locale-aware getters
- `WorshipStep` (line 25): Add `titleEnglish`, `instructionEnglish`, `meaningEnglish` + getters `getTitle(locale)`, `getInstruction(locale)`, `getMeaning(locale)`. Make `statusLabel` (line 51) locale-aware (ফরজ/Fard, সুন্নাত/Sunnah, মুস্তাহাব/Mustahab)
- `WorshipSection` (line 97): Add `titleEnglish`, `descriptionEnglish`, `itemsEnglish` + locale getters
- `WorshipDua` (line 114): Add `titleEnglish`, `meaningEnglish`, `whenEnglish` + locale getters
- `Reference` (line 2): **No changes needed** — `source`, `citation`, `fullText` are language-neutral academic citations

### 3.2 MonajatModel
**File:** `lib/models/monajat_model.dart`
- Add `titleEnglish`, `meaningEnglish`, `contextEnglish` + locale getters
- (`arabic` and `pronunciation` are language-neutral — no changes)

### 3.3 AyatModel, DuaModel, UmrahModel
**Files:** `lib/models/ayat_model.dart`, `dua_model.dart`, `umrah_model.dart`
- AyatModel: Add `titleEnglish`, `surahNameEnglish`, `englishTransliteration`, `englishMeaning`, `categoryEnglish` + locale getters + update `fromJson`/`toJson`
- DuaModel: Add `titleEnglish`, `englishTransliteration`, `englishMeaning`, `categoryEnglish` + locale getters + update `fromJson`/`toJson`
- UmrahDuaModel: Add `titleEnglish`, `englishTransliteration`, `englishMeaning`, `occasionEnglish` + locale getters + update `fromJson`/`toJson`
- UmrahSectionModel: Add `titleEnglish`, `descriptionEnglish`, `rulesEnglish` + locale getters + update `fromJson`/`toJson`

### 3.4 EbadatTopic
**File:** `lib/models/ebadat_topic.dart`
- Already has `titleBangla` and `titleEnglish`. Add locale-aware getter `getTitle(locale)`

---

## Phase 4: Add English Content to Data Files (14 files + 3 JSON assets)

For each Dart data file, add English parallel fields to every constructor call. Files like `namaz_data.dart` and `wudu_data.dart` already pass `titleEnglish` — body content (introduction, conditions, steps, etc.) is Bengali only and needs English additions.

| # | File | Content | Notes |
|---|------|---------|-------|
| 1 | `lib/data/namaz_data.dart` | Prayer guide (largest) | `titleEnglish` exists; body Bengali only |
| 2 | `lib/data/wudu_data.dart` | Ablution guide | `titleEnglish` exists; body Bengali only |
| 3 | `lib/data/ghusl_data.dart` | Bathing guide | |
| 4 | `lib/data/tayammum_data.dart` | Dry ablution | |
| 5 | `lib/data/monajat_data.dart` | Supplications | No English fields at all |
| 6 | `lib/data/tahajjud_data.dart` | Night prayer | |
| 7 | `lib/data/witr_data.dart` | Witr prayer | |
| 8 | `lib/data/janazah_data.dart` | Funeral prayer | |
| 9 | `lib/data/qasr_data.dart` | Shortened prayer | |
| 10 | `lib/data/tahiyyatul_masjid_data.dart` | Mosque greeting prayer | |
| 11 | `lib/data/attahiyatu_data.dart` | Tashahhud | |
| 12 | `lib/data/zakat_data.dart` | Charity guide | |
| 13 | `lib/data/eman_data.dart` | Faith pillars | |
| 14 | `lib/data/ramadan_roja_data.dart` | Ramadan fasting | |

**JSON assets** (in `assets/data/`):

| # | File | Content |
|---|------|---------|
| 15 | `assets/data/ayats.json` | Quranic verses |
| 16 | `assets/data/duas.json` | Supplications |
| 17 | `assets/data/umrah.json` | Umrah guide |

---

## Phase 5: Replace Hardcoded UI Strings

Replace hardcoded text with `AppLocalizations.of(context).keyName` (or `LocaleProvider` for no-context services):

| Area | Files | Key Strings |
|------|-------|-------------|
| Bottom nav | `lib/main.dart` (lines 111-118) | `'Home'`, `'Ebadat'`, `'Calendar'`, `'Profile'` |
| Home screen | `lib/screens/home_screen.dart` | `'Jamaat Time'`, `'Prayer Times'`, `'Sahri & Iftar Times'`, `'Loading jamaat times...'`, `'GPS Mode: No jamaat times'`, `'Detecting...'`, prayer name display mappings |
| Settings | `lib/screens/settings_screen.dart` | `'Settings'`, `'Prayer Calculation'`, `'Prayer time school'`, `'Hanafi'`/`'Shafi'`, `'Bangladesh Hijri date offset'`, `'Notifications'`, `'Prayer reminder sound'`/`'Jamaat reminder sound'`, sound option labels, `'Focus Guard'` |
| Profile content | `lib/widgets/profile/profile_logged_in_content.dart` | `'Account'`, `'Main Options'`, `'My Bookmarks'`, `'Saved ayat and dua for quick reading'`, `'Settings'`, `'Admin Tools'`, `'Manage Users'`, `'Edit/Import Data'`, `'Logout'` |
| Widget service | `lib/services/widget_service.dart` (uses `LocaleProvider`) | `'Coming Dhuhr'`, `'$period Time Remaining'`, `'$name Jamaat in'`, `'Jamaat is Over'`, `'Jamaat N/A'` |
| Ebadat | `lib/screens/ebadat/ebadat_screen.dart` | `'ইবাদত'` tab title |
| Worship guides | `lib/screens/ebadat/topics/worship_guide_screen.dart` | Section headers, share error messages |
| Prayer table | `lib/widgets/prayer_time_table.dart` | Column headers |
| Prayer countdown | `lib/widgets/prayer_countdown_widget.dart` | Period name labels |
| Sahri/Iftar | `lib/widgets/sahri_iftar_widget.dart` | `'Sahri Ends'`, `'Iftar Begins'`, `'Remaining Time'`, `'Tap card for focus'`, `'Sahri Focus'`/`'Iftar Focus'`, `'Sehri time finished'` |
| Forbidden times | `lib/widgets/forbidden_times_widget.dart` | `'Forbidden Prayer Times'`, `'Active'`/`'Next'` |
| Notifications | `lib/services/notification_service.dart` (uses `LocaleProvider`) | `'Fajr Prayer'`/`'Fajr time remaining 20 minutes.'` (line 625), all 5 prayer notifications, `'$name Jamaat'`/`'$name Jamaat is in 10 minutes.'` (line 782) |
| Bookmarks | `lib/screens/bookmarks_screen.dart` | `'আমার বুকমার্ক'`, `'আয়াত'`, `'দোয়া'`, error/retry labels |
| Admin | `lib/screens/admin_jamaat_panel.dart` | Section headers, button labels |
| Calendar | `lib/screens/calendar_screen.dart` | Prayer name order, Hijri month names |
| Calendar card | `lib/widgets/calendar_selected_date_card.dart` | `'Bangla'`, `'Hijri'` chip labels |
| Ebadat widgets | `lib/widgets/ebadat/*.dart` | Card titles, guide display labels |
| Ebadat detail screens | `lib/screens/ebadat/ayat_detail_screen.dart`, `dua_detail_screen.dart`, `umrah_detail_screen.dart`, `monajat_detail_screen.dart`, `monajat_list_screen.dart` | Bengali section headers (`'বাংলা উচ্চারণ'`, `'বাংলা অর্থ'`, `'বিবরণ'`, `'নিয়মাবলী'`, etc.) |

---

## Phase 6: Data Display Widgets → Use Locale Getters

Update all widgets that display data model content to use locale-aware getters:

- `worship_guide_screen.dart` → `step.getTitle(locale)` instead of `step.titleBangla`
- `ebadat_topic_card.dart` → `topic.getTitle(locale)` instead of `topic.titleBangla`
- `monajat_list_screen.dart` / `monajat_detail_screen.dart` → `monajat.getTitle(locale)`, `monajat.getMeaning(locale)`
- `ayat_detail_screen.dart` / `ayat_list_screen.dart` → locale-aware fields
- `dua_detail_screen.dart` / `dua_list_screen.dart` → locale-aware fields
- `umrah_detail_screen.dart` / `umrah_list_screen.dart` → locale-aware fields
- `worship_step_card.dart` → `step.getStatusLabel(locale)` instead of `step.statusLabel`

---

## Phase 7: Test Updates

### 7.1 Create locale-aware test helper
**New file:** `test/helpers/localized_test_wrapper.dart`
- Reusable wrapper providing `MaterialApp` with localization delegates and a configurable locale
- All widget tests that assert on visible text need this wrapper

### 7.2 Update affected test files

**Must update (hardcoded text assertions):**

1. **`test/sahri_iftar_widget_test.dart`** — 6 assertions:
   - `find.text('Sahri Ends')` (line 28)
   - `find.text('Iftar Begins')` (line 29)
   - `find.text('Remaining Time')` (line 30)
   - `find.text('Tap card for focus')` (line 31)
   - `find.text('Sahri Focus')` (line 51)
   - `find.text('Sehri time finished')` (line 71)

2. **`test/widgets/calendar_selected_date_card_test.dart`** — 3 assertions:
   - `find.text('Bangla')` (line 39)
   - `find.text('Hijri')` (line 40)
   - `find.text('English')` (line 45)

3. **`test/services/widget_service_test.dart`** — 7 assertions on WidgetService string output:
   - `data.remainingLabel, 'Fajr Time Remaining'` (line 38)
   - `data.remainingLabel, 'Coming Dhuhr'` (line 59)
   - `data.jamaatLabel, 'Fajr Jamaat in'` (line 78)
   - Tests need `LocaleProvider().locale = 'en'` set before running, or assertions updated to expect Bengali defaults

**Safe (no changes needed):**
- `test/widgets/profile_logged_in_content_test.dart` — uses Key-based assertions
- `test/services/hijri_date_converter_test.dart` — numeric/date logic
- `test/services/settings_service_test.dart` — SharedPreferences tests

---

## Implementation Order (Recommended)

1. **Phase 1** → Foundation (get gen-l10n working with ~10 test keys)
2. **Phase 2** → Language picker in settings_screen.dart (test switching immediately)
3. **Phase 5** → UI strings (screen by screen, starting with main.dart nav)
4. **Phase 3** → Make models bilingual
5. **Phase 4** → Add English content to data files (one file at a time)
6. **Phase 6** → Wire data display widgets to use locale getters
7. **Phase 7** → Update tests to work with localization

---

## Verification

1. Run `flutter gen-l10n` — no errors
2. Run `flutter build apk --debug` — compiles clean
3. Switch to English → all screens render without overflow, correct text
4. Switch to Bengali → all screens render correctly (existing behavior preserved)
5. Kill app & reopen → locale persists
6. Notifications show correct language text (change language, verify scheduled notification content)
7. Prayer countdown/calculation logic unchanged (internal keys stay English)
8. Share/copy text uses current locale
9. Home screen widget labels reflect current language
10. All tests pass: `flutter test` — zero failures
