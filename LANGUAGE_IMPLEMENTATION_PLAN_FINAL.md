# Language Selection — Final Implementation Plan (v2)

**Version:** 2.0 (flagship standard)
**Supersedes:** `language.md` v1
**Audit reference:** `LANGUAGE_PLAN_AUDIT.md`
**Target app:** Jamaat Time (Flutter, Android + iOS + Windows)
**Languages:** Bengali (`bn`) — runtime default; English (`en`) — template/fallback

---

## 0. Executive Summary

Ship a complete Bengali/English toggle that covers:

- UI labels (~200 strings across 20+ widgets, 12+ screens) via Flutter's official ARB + gen-l10n pipeline.
- Islamic content (~3,400 lines in 14 Dart data files + 3 JSON assets) via bilingual model fields and locale-aware getters.
- Notifications, home-screen widget (Android, background isolate), prayer countdown, share/copy text, and search/filter — all driven by the same locale source.
- A persisted user preference, defaulting to Bengali on first launch, with no visible flicker at cold start.

The plan below resolves every issue raised in the audit report and locks every open decision so the work can start immediately.

---

## 1. Locked Decisions (no ambiguity remaining)

| # | Decision | Value |
|---|----------|-------|
| D1 | Supported locales | `Locale('bn')`, `Locale('en')` |
| D2 | ARB template | `app_en.arb` (gen-l10n fallback) |
| D3 | Runtime default | `Locale('bn')` when nothing is persisted |
| D4 | Persisted values | `'bn'` or `'en'` only (no `null`). First launch writes `'bn'`. |
| D5 | Settings dropdown | Two items: `বাংলা` and `English`. No "default" item. |
| D6 | Numeral policy | **Always Western digits** (0–9) for times, counts, dates — across both locales. Achieved by passing `Locale('en')` to `DateFormat`/`NumberFormat` for time/number rendering. |
| D7 | Font policy | Keep existing `google_fonts` setup. Add `GoogleFonts.hindSiliguri` (Bengali-capable) as the default family for locale `bn`; keep `GoogleFonts.inter` (or current default) for `en`. Selected in `MyApp.build` via locale. |
| D8 | Key naming | Prefixes: `nav_`, `prayer_`, `settings_`, `countdown_`, `ebadat_`, `notification_`, `error_`, `profile_`, `sahri_iftar_`, `forbidden_`, `widget_`, `share_`, `bookmark_`, `admin_`, `calendar_`. |
| D9 | Notification strings | Resolved at **schedule time** using the locale persisted in SharedPreferences. On language change, call `NotificationService.scheduleAllNotifications(...)` — which already calls `cancelAllNotifications()` first (notification_service.dart:808-813). |
| D10 | Widget labels (home screen widget / Android) | Background isolate reads locale directly from SharedPreferences and passes it as a parameter through `computeWidgetPreviewData`. No singleton is used in the isolate. |
| D11 | Locale access inside isolates | A static helper `LocalePrefs.readSync(prefs)` / `LocalePrefs.read()` loads `'app_locale'` from `SharedPreferences`. No cross-isolate singleton. |
| D12 | Locale access inside UI | A `ValueNotifier<Locale>` in `AppLocaleController` (singleton, UI-thread only). `MaterialApp` rebuilds via `ValueListenableBuilder`. |
| D13 | Content fields on Models | All `*English` fields are **nullable**. Locale-aware getters fall back to the Bengali value when the English value is missing. This allows Phase 3 (model changes) to merge before Phase 4 (content population) without breaking the app. |
| D14 | JSON schema | Add `"schemaVersion": 2` at the top level of `ayats.json`, `duas.json`, `umrah.json`. `fromJson` reads v2-only fields as nullable so old caches keep working. |
| D15 | Bootstrap | `main()` awaits a synchronous prefs read before `runApp`, so the first frame already has the correct locale. No splash/FutureBuilder flicker. |
| D16 | Arabic text | Never translated, never affected by locale. Stored in its own fields (`arabicText`). |
| D17 | References/citations | `Reference.source`, `.citation`, `.fullText` treated as content — audited per data file during Phase 4; English mirrors added where any Bengali prose is present. |
| D18 | Numerals inside notification bodies | Also Western digits (D6). |
| D19 | Category filtering | Categories in JSON store both `categoryBangla` and `categoryEnglish`. `EbadatDataService` filters/searches using the active locale. |
| D20 | Test strategy | Every PR is self-sufficient — code + tests in the same commit. Phase 7 is about hardening, not enabling. |
| D21 | Rollout gate | Feature is behind a build-time flag (`bool kLanguageSwitchEnabled = true;` in `core/feature_flags.dart`) so it can be toggled off in a hotfix if a regression slips through. Removed after one stable release. |

---

## 2. Architecture

```
 ┌──────────────────────────────────────────────────────────┐
 │                 SettingsService (UI isolate)             │
 │  getLocale()/setLocale(String) + onSettingsChanged       │
 │  Writes key 'app_locale' in SharedPreferences            │
 └──────────────┬───────────────────────────────────────────┘
                │ stream
 ┌──────────────▼───────────────────────────────────────────┐
 │          AppLocaleController (UI singleton)              │
 │  ValueNotifier<Locale>   +  current getter               │
 └──────────────┬───────────────────────────────────────────┘
                │ rebuilds
 ┌──────────────▼────────────────┐   ┌───────────────────────────┐
 │  MaterialApp (locale param)   │   │ NotificationService       │
 │  gen-l10n AppLocalizations    │   │ reads controller.current  │
 │  Google Fonts per locale      │   │ at schedule time          │
 └───────────────────────────────┘   └───────────────────────────┘

 ┌──────────────────────────────────────────────────────────┐
 │  backgroundCallback (widget refresh isolate)             │
 │  reads SharedPreferences directly → Locale('bn'|'en')    │
 │  passes Locale into computeWidgetPreviewData(...)        │
 └──────────────────────────────────────────────────────────┘
```

Principles:
- UI code goes through `AppLocalizations.of(context)`.
- No-context code (notifications, background widget, isolate callbacks) accepts a `Locale` parameter and reads ARB strings via the pattern described in §6.
- Model content uses bilingual fields + `getX(locale)` helpers.

---

## 3. File Inventory (authoritative)

### 3.1 New files
| Path | Purpose |
|------|---------|
| `l10n.yaml` | gen-l10n config |
| `lib/l10n/app_en.arb` | Template & English strings |
| `lib/l10n/app_bn.arb` | Bengali strings |
| `lib/core/feature_flags.dart` | `kLanguageSwitchEnabled` (D21) |
| `lib/core/locale_prefs.dart` | Isolate-safe SharedPreferences locale helper (D11) |
| `lib/core/app_locale_controller.dart` | `ValueNotifier<Locale>` + boot helper (D12) |
| `lib/core/app_text.dart` | Locale-aware static string provider for no-context code (§6) |
| `test/helpers/localized_test_wrapper.dart` | Reusable test harness |
| `test/core/locale_prefs_test.dart` | Unit tests for isolate-safe helper |
| `test/core/app_locale_controller_test.dart` | Unit tests for UI controller |

### 3.2 Modified files (UI)
`lib/main.dart`, `lib/screens/home_screen.dart`, `lib/screens/settings_screen.dart`, `lib/screens/calendar_screen.dart`, `lib/screens/bookmarks_screen.dart`, `lib/screens/admin_jamaat_panel.dart`, `lib/screens/ebadat/ebadat_screen.dart`, `lib/screens/ebadat/ayat_detail_screen.dart`, `lib/screens/ebadat/dua_detail_screen.dart`, `lib/screens/ebadat/umrah_detail_screen.dart`, `lib/screens/ebadat/tabs/ayat_tab.dart`, `lib/screens/ebadat/tabs/dua_tab.dart`, `lib/screens/ebadat/tabs/umrah_tab.dart`, `lib/screens/ebadat/topics/ayat_list_screen.dart`, `lib/screens/ebadat/topics/dua_list_screen.dart`, `lib/screens/ebadat/topics/monajat_list_screen.dart`, `lib/screens/ebadat/topics/monajat_detail_screen.dart`, `lib/screens/ebadat/topics/umrah_list_screen.dart`, `lib/screens/ebadat/topics/worship_guide_screen.dart`, `lib/screens/ebadat/topics/zakat_calculator_screen.dart`, `lib/screens/ebadat/topics/topic_placeholder_screen.dart`, `lib/widgets/prayer_time_table.dart`, `lib/widgets/prayer_countdown_widget.dart`, `lib/widgets/sahri_iftar_widget.dart`, `lib/widgets/forbidden_times_widget.dart`, `lib/widgets/calendar_selected_date_card.dart`, `lib/widgets/ebadat/*.dart`, `lib/widgets/profile/profile_logged_in_content.dart`.

### 3.3 Modified files (services)
`lib/services/settings_service.dart`, `lib/services/notification_service.dart`, `lib/services/widget_service.dart`, `lib/services/ebadat_data_service.dart`.

### 3.4 Modified files (models)
`lib/models/worship_guide_model.dart`, `lib/models/monajat_model.dart`, `lib/models/ayat_model.dart`, `lib/models/dua_model.dart`, `lib/models/umrah_model.dart`, `lib/models/ebadat_topic.dart`.

### 3.5 Modified files (data)
`lib/data/namaz_data.dart`, `wudu_data.dart`, `ghusl_data.dart`, `tayammum_data.dart`, `monajat_data.dart`, `tahajjud_data.dart`, `witr_data.dart`, `janazah_data.dart`, `qasr_data.dart`, `tahiyyatul_masjid_data.dart`, `attahiyatu_data.dart`, `zakat_data.dart`, `eman_data.dart`, `ramadan_roja_data.dart`, `assets/data/ayats.json`, `duas.json`, `umrah.json`.

### 3.6 Config
`pubspec.yaml`, `ios/Runner/Info.plist`.

### 3.7 Test files (new or updated)
`test/services/settings_service_test.dart`, `test/services/widget_service_test.dart`, `test/services/notification_service_test.dart` (new), `test/services/ebadat_data_service_test.dart` (new), `test/sahri_iftar_widget_test.dart`, `test/widgets/calendar_selected_date_card_test.dart`, `test/widgets/language_dropdown_test.dart` (new), `test/screens/ebadat/ayat_tab_test.dart` (new), `test/screens/ebadat/dua_tab_test.dart` (new), `test/screens/ebadat/umrah_tab_test.dart` (new).

---

## 4. Phase 1 — Foundation

### 4.1 Dependencies (`pubspec.yaml`)
- Add under `dependencies:`:
  ```yaml
  flutter_localizations:
    sdk: flutter
  ```
- Add under the top-level `flutter:` key:
  ```yaml
  generate: true
  ```
  (Do not confuse with `generate: true` under `flutter_launcher_icons:` at lines 123/128/132 — unrelated.)

### 4.2 `l10n.yaml`
```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
synthetic-package: false
```
(`synthetic-package: false` places generated code under `lib/l10n/` so we can also reference it from non-UI contexts.)

### 4.3 ARB files
Seed with ~15 keys covering nav, bottom nav, settings title, and Jamaat widget labels. Validates pipeline end-to-end. Full key set populated incrementally as each screen is migrated.

### 4.4 `lib/core/feature_flags.dart`
```dart
const bool kLanguageSwitchEnabled = true;
```
(§D21)

### 4.5 `lib/core/locale_prefs.dart` (isolate-safe)
```dart
class LocalePrefs {
  static const String key = 'app_locale';
  static const String defaultCode = 'bn';

  static String readFromPrefs(SharedPreferences prefs) =>
      prefs.getString(key) ?? defaultCode;

  static Future<String> read() async =>
      readFromPrefs(await SharedPreferences.getInstance());

  static Future<void> write(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, code);
  }

  static Locale toLocale(String code) =>
      code == 'en' ? const Locale('en') : const Locale('bn');
}
```
Used by both the UI isolate and the widget background isolate.

### 4.6 `lib/core/app_locale_controller.dart` (UI-thread only)
```dart
class AppLocaleController {
  AppLocaleController._(this.notifier);
  static late AppLocaleController instance;

  final ValueNotifier<Locale> notifier;
  Locale get current => notifier.value;

  static Future<void> bootstrap() async {
    final code = await LocalePrefs.read();
    instance = AppLocaleController._(ValueNotifier(LocalePrefs.toLocale(code)));
  }

  Future<void> set(String code) async {
    await LocalePrefs.write(code);
    notifier.value = LocalePrefs.toLocale(code);
  }
}
```
No `StreamSubscription` is needed because `ValueListenableBuilder` subscribes automatically and releases on widget disposal.

### 4.7 `SettingsService` additions
Add, following the exact pattern used by `_madhabKey` / `setMadhab`:
```dart
static const String _localeKey = 'app_locale';
Future<String> getLocale() async { ... return prefs.getString(_localeKey) ?? 'bn'; }
Future<void> setLocale(String code) async { ...setString...; _controller.add(null); }
```
Note: `SettingsService.getLocale` and `LocalePrefs.read` must agree on the same key (`'app_locale'`) and default (`'bn'`). A lint-time `assert` in a debug `SettingsService` constructor enforces it.

### 4.8 Bootstrap in `main.dart` (D15)
Replace current `main()`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ... existing initialization (Firebase, notifications, widget callback) ...
  await AppLocaleController.bootstrap();
  runApp(const MyApp());
}
```

Convert `MyApp` to `StatelessWidget` that consumes the controller:
```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocaleController.instance.notifier,
      builder: (context, locale, _) => MaterialApp(
        title: 'Jamaat Time',
        theme: _themeFor(locale),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MainScaffold(),
      ),
    );
  }
}
```
`_themeFor(locale)` applies the Bengali-capable font family when `locale.languageCode == 'bn'` (D7).

### 4.9 iOS (`ios/Runner/Info.plist`)
```xml
<key>CFBundleLocalizations</key>
<array>
  <string>bn</string>
  <string>en</string>
</array>
```

### 4.10 Acceptance gates for Phase 1
- `flutter pub get` succeeds.
- `flutter gen-l10n` produces `lib/l10n/app_localizations.dart`.
- Cold launch shows Bengali UI; switching the persisted key to `en` in prefs and relaunching shows English UI.
- No changes in widget-under-home-screen behavior yet (still shows hardcoded English — fixed in Phase 5).

---

## 5. Phase 2 — Language Picker UI

**File:** `lib/screens/settings_screen.dart` (insert after "Prayer Calculation" section, before "Notifications").

- New `_buildSectionCard` with `icon: Icons.language`, `title: AppLocalizations.of(context).settings_languageSection`.
- `_buildDropdownField<String>` with two items (D5):
  - `'bn'` → `AppLocalizations.of(context).settings_languageBangla`
  - `'en'` → `AppLocalizations.of(context).settings_languageEnglish`
- Local state `String _locale = 'bn'`; load in `_loadSettings` via `_settingsService.getLocale()`.
- On change:
  ```dart
  await _settingsService.setLocale(val);
  await AppLocaleController.instance.set(val);
  await _notificationService.scheduleAllNotifications(times, jamaatTimes); // D9
  ```
  (If `times`/`jamaatTimes` are not held by this screen, fire an event through `SettingsService.onSettingsChanged` — which `HomeScreen` already listens to via `_handleNotificationSettingsChange` — and add a parallel `_handleLocaleChange` that replays the same reschedule.)

### Acceptance gates for Phase 2
- Dropdown renders correctly in both locales.
- Selecting a value persists across app restart.
- Selecting a value immediately rebuilds `MaterialApp` (visible: bottom nav labels flip).

---

## 6. Phase 3 — No-Context String Access (`AppText`)

`NotificationService` and `WidgetService` cannot use `AppLocalizations.of(context)`. We provide:

`lib/core/app_text.dart`:
```dart
class AppText {
  static AppLocalizations of(Locale locale) =>
      lookupAppLocalizations(locale);
}
```
Consumers call, e.g.:
```dart
final strings = AppText.of(locale);
final title = strings.notification_fajrTitle;
```

`lookupAppLocalizations` is the gen-l10n generated function; `synthetic-package: false` (§4.2) makes it importable.

Unit test: `AppText.of(Locale('bn')).notification_fajrTitle` == `'ফজর নামাজ'`, same for `en`.

---

## 7. Phase 4 — Make Models Bilingual

Pattern (applied to every model below): add optional `*English` fields, add `getX(Locale locale)` that returns the English value when locale is `en` and the English value is non-null; otherwise returns the Bengali value. `==` and `hashCode` remain keyed on `id`.

Files (audited against the actual codebase — see LANGUAGE_PLAN_AUDIT §1 for path verification):

- `lib/models/worship_guide_model.dart`:
  - `WorshipGuideModel`: adds `introductionEnglish`, `conditionsEnglish`, `fardActsEnglish`, `sunnahActsEnglish`, `commonMistakesEnglish`, `specialRulingsEnglish`, `invalidatorsEnglish` (all `List<String>?` or `String?`), plus `getIntroduction(locale)` etc.
  - `WorshipStep`: adds `titleEnglish`, `instructionEnglish`, `meaningEnglish`; `statusLabel` becomes `getStatusLabel(Locale locale)` returning `ফরজ`/`সুন্নাত`/`মুস্তাহাব` vs `Fard`/`Sunnah`/`Mustahab`.
  - `WorshipSection`: adds `titleEnglish`, `descriptionEnglish`, `itemsEnglish` + getters.
  - `WorshipDua`: adds `titleEnglish`, `meaningEnglish`, `whenEnglish` + getters.
  - `Reference`: decision deferred until Phase 5 audit — if `fullText` contains Bengali prose in any data file, add `fullTextEnglish`; otherwise no change.
- `lib/models/monajat_model.dart`: adds `titleEnglish`, `meaningEnglish`, `contextEnglish` + getters.
- `lib/models/ayat_model.dart`: adds `titleEnglish`, `surahNameEnglish`, `englishTransliteration`, `englishMeaning`, `categoryEnglish`, `categoryBangla` (keep `category` for backward compatibility and point it to `categoryBangla`). Update `fromJson`/`toJson` with all new fields **optional** (null-safe).
- `lib/models/dua_model.dart`: adds `titleEnglish`, `englishTransliteration`, `englishMeaning`, `categoryEnglish`, `categoryBangla`. Same JSON-optional pattern.
- `lib/models/umrah_model.dart`:
  - `UmrahDuaModel`: adds `titleEnglish`, `englishTransliteration`, `englishMeaning`, `occasionEnglish`.
  - `UmrahSectionModel`: adds `titleEnglish`, `descriptionEnglish`, `rulesEnglish`.
- `lib/models/ebadat_topic.dart`: already has `titleBangla`/`titleEnglish` — add `getTitle(Locale locale)`.

Arabic fields (`arabicText`, `surahNameArabic`, `pronunciation`) are untouched (D16).

### Acceptance gates for Phase 4
- `flutter build apk --debug` compiles.
- Existing unit tests still pass — model identity (`==`) unchanged.
- Loading `ayats.json` in its current (v1) form does not crash — nullable getters short-circuit to Bengali (D13).

---

## 8. Phase 5 — UI String Replacement

Each row below is a commit boundary. Every commit replaces the strings, adds the ARB keys, and updates the matching test file in the same PR (D20).

| # | Area | File(s) (exact paths) | Strings |
|---|------|-----------------------|---------|
| 1 | Bottom nav | `lib/main.dart` | `Home`, `Ebadat`, `Calendar`, `Profile` |
| 2 | Home screen | `lib/screens/home_screen.dart` | `Jamaat Time`, `Prayer Times`, `Sahri & Iftar Times`, `Loading jamaat times...`, `GPS Mode: No jamaat times`, `Detecting...`, prayer name mappings |
| 3 | Settings | `lib/screens/settings_screen.dart` | `Settings`, `Prayer Calculation`, `Prayer time school`, `Hanafi`/`Shafi`, `Bangladesh Hijri date offset`, `Notifications`, `Prayer reminder sound`/`Jamaat reminder sound`, sound option labels, `Focus Guard` |
| 4 | Profile | `lib/widgets/profile/profile_logged_in_content.dart` | `Account`, `Main Options`, `My Bookmarks`, `Saved ayat and dua for quick reading`, `Settings`, `Admin Tools`, `Manage Users`, `Edit/Import Data`, `Logout` |
| 5 | Prayer table | `lib/widgets/prayer_time_table.dart` | Column headers |
| 6 | Countdown | `lib/widgets/prayer_countdown_widget.dart` | Period name labels |
| 7 | Sahri/Iftar | `lib/widgets/sahri_iftar_widget.dart` | `Sahri Ends`, `Iftar Begins`, `Remaining Time`, `Tap card for focus`, `Sahri Focus`/`Iftar Focus`, `Sehri time finished` |
| 8 | Forbidden | `lib/widgets/forbidden_times_widget.dart` | `Forbidden Prayer Times`, `Active`, `Next` |
| 9 | Calendar | `lib/screens/calendar_screen.dart` | Prayer order, Hijri month names |
| 10 | Calendar card | `lib/widgets/calendar_selected_date_card.dart` | `Bangla`, `Hijri`, `English` chip labels |
| 11 | Bookmarks | `lib/screens/bookmarks_screen.dart` | `আমার বুকমার্ক`, `আয়াত`, `দোয়া`, error/retry labels |
| 12 | Admin | `lib/screens/admin_jamaat_panel.dart` | Section headers, buttons |
| 13 | Ebadat tab container | `lib/screens/ebadat/ebadat_screen.dart` | `ইবাদত`, AppBar title, tab headers |
| 14 | **Ayat tab** | `lib/screens/ebadat/tabs/ayat_tab.dart` | `ডেটা লোড করতে ব্যর্থ`, `পুনরায় চেষ্টা করুন`, `এই ক্যাটাগরিতে কোনো আয়াত নেই`, `কোনো আয়াত পাওয়া যায়নি`, `ফিল্টার মুছে ফেলুন`, `সব` chip, category chip labels |
| 15 | **Dua tab** | `lib/screens/ebadat/tabs/dua_tab.dart` | Same pattern as Ayat tab |
| 16 | **Umrah tab** | `lib/screens/ebadat/tabs/umrah_tab.dart` | Same pattern |
| 17 | Worship guide | `lib/screens/ebadat/topics/worship_guide_screen.dart` | Section headers, share error messages |
| 18 | Ayat detail | `lib/screens/ebadat/ayat_detail_screen.dart` | `বাংলা উচ্চারণ`, `বাংলা অর্থ`, `বিবরণ`, `নিয়মাবলী`, share/copy labels |
| 19 | Dua detail | `lib/screens/ebadat/dua_detail_screen.dart` | Same |
| 20 | Umrah detail | `lib/screens/ebadat/umrah_detail_screen.dart` | Same |
| 21 | Monajat list | `lib/screens/ebadat/topics/monajat_list_screen.dart` | Section headers |
| 22 | Monajat detail | `lib/screens/ebadat/topics/monajat_detail_screen.dart` | Same |
| 23 | Ayat list | `lib/screens/ebadat/topics/ayat_list_screen.dart` | Same |
| 24 | Dua list | `lib/screens/ebadat/topics/dua_list_screen.dart` | Same |
| 25 | Umrah list | `lib/screens/ebadat/topics/umrah_list_screen.dart` | Same |
| 26 | Zakat calc | `lib/screens/ebadat/topics/zakat_calculator_screen.dart` | All prose |
| 27 | Placeholder | `lib/screens/ebadat/topics/topic_placeholder_screen.dart` | Placeholder text |
| 28 | Ebadat widgets | `lib/widgets/ebadat/*.dart` | Card titles, guide display labels, `loading_card.dart` labels |

### 5.x Non-context consumers (use `AppText` from §6)
- **`lib/services/notification_service.dart`** — replace hardcoded `'Fajr Prayer'`/`'Fajr time remaining 20 minutes.'` (line 625) and all 5 prayer + Jamaat notifications (line 782). Each call site reads `locale` from `AppLocaleController.instance.current` (UI path) or from `LocalePrefs.read()` (background path).
- **`lib/services/widget_service.dart`** — add `Locale locale` parameter to `computeWidgetPreviewData`, `_computeJamaatWidgetState`, and the `_JamaatWidgetState` constants (converted to factory constructors). The top-level `backgroundCallback` reads `LocalePrefs.readFromPrefs(prefs)` and passes the derived `Locale` into `updateWidgetData`.
  - Android widget layout must accept the localized string as a widget-data value (already does via `HomeWidget.saveWidgetData<String>`).
  - After `setLocale`, call `WidgetService.forceRefresh()` (new convenience wrapper around `updateWidgetData` using current prayer-times cache) so the home-screen widget updates immediately.

### Acceptance gates for Phase 5
- `flutter test` — green.
- Manual: switch language, every screen listed above flips. No overflow, no tofu (Bengali font renders properly — D7).
- Android home-screen widget labels flip within 2 seconds of language change without waiting for the next 1-minute refresh.

---

## 9. Phase 6 — Ebadat Data Service localization

**File:** `lib/services/ebadat_data_service.dart`.

- Change signature:
  - `Future<List<String>> getAyatCategories({required Locale locale})`
  - `Future<List<String>> getDuaCategories({required Locale locale})`
  - `Future<List<AyatModel>> getAyatsByCategory(String category, {required Locale locale})`
  - `Future<List<DuaModel>> getDuasByCategory(String category, {required Locale locale})`
  - `Future<List<AyatModel>> searchAyats(String query, {required Locale locale})`
  - `Future<List<DuaModel>> searchDuas(String query, {required Locale locale})`
- Implementation uses `locale.languageCode == 'en' ? ayat.categoryEnglish ?? ayat.categoryBangla : ayat.categoryBangla` for filtering/search fields.
- Call sites (`ayat_tab.dart`, `dua_tab.dart`, `umrah_tab.dart`, any bookmark-by-category lookup in `bookmarks_screen.dart`) pass `Localizations.localeOf(context)`.

Widget display (existing items mentioned in plan v1):
- `worship_guide_screen.dart` → `step.getTitle(locale)`
- `ebadat_topic_card.dart` → `topic.getTitle(locale)`
- Monajat / Ayat / Dua / Umrah list and detail screens → locale-aware fields
- `worship_step_card.dart` → `step.getStatusLabel(locale)`

### Acceptance gates for Phase 6
- In English mode: category filter chips show English labels, search matches English query tokens.
- In Bengali mode: behavior unchanged from today.

---

## 10. Phase 7 — Add English Content (Not Now)

Each data file is a separate PR. Nullability from D13 means partial merges never crash the app — English mode just silently falls back to Bengali until the file is complete.

Dart data files (14): `namaz_data.dart`, `wudu_data.dart`, `ghusl_data.dart`, `tayammum_data.dart`, `monajat_data.dart`, `tahajjud_data.dart`, `witr_data.dart`, `janazah_data.dart`, `qasr_data.dart`, `tahiyyatul_masjid_data.dart`, `attahiyatu_data.dart`, `zakat_data.dart`, `eman_data.dart`, `ramadan_roja_data.dart`.

JSON assets (3): `assets/data/ayats.json`, `duas.json`, `umrah.json`.

For JSON (D14):
```json
{
  "schemaVersion": 2,
  "ayats": [
    {
      "id": 1,
      "titleBangla": "...",
      "titleEnglish": "...",
      "categoryBangla": "...",
      "categoryEnglish": "...",
      ...
    }
  ]
}
```

`fromJson` reads `schemaVersion` — if absent, assume v1 and leave English fields `null`. Log a debug warning once per session: `'Loaded v1 ayats.json; English strings will fall back to Bengali'`.

### Acceptance gates for Phase 10
- Every list item in every Ebadat screen shows English text in English mode.
- Nothing in Bengali mode has regressed.
- JSON schema v2 is valid JSON (`python -m json.tool` or `flutter test` asset-loading test).

---

## 11. Phase 8 — Tests

### 11.1 New file: `test/helpers/localized_test_wrapper.dart`
Provides:
- `Widget wrapWithLocale({required Widget child, Locale locale = const Locale('en')})` returning a `MaterialApp` preconfigured with all delegates and supported locales.
- Helper to set `SharedPreferences.setMockInitialValues({'app_locale': 'en'})` before tests.

### 11.2 Unit tests (new)
- `test/core/locale_prefs_test.dart`:
  - `read()` defaults to `'bn'` when unset.
  - `write('en')` persists and `read()` returns `'en'`.
  - `toLocale('en')` → `Locale('en')`.
- `test/core/app_locale_controller_test.dart`:
  - `bootstrap()` reads saved value.
  - `set('en')` updates notifier and persists.
- `test/services/settings_service_test.dart` (extend):
  - `getLocale()` default is `'bn'`.
  - `setLocale('en')` persists, subsequent `getLocale()` returns `'en'`.
  - `onSettingsChanged` fires after `setLocale`.
- `test/services/ebadat_data_service_test.dart` (new):
  - `searchAyats('mercy', locale: en)` returns entries whose `englishMeaning` contains `'mercy'`.
  - `searchAyats('রহমত', locale: bn)` returns entries whose `banglaMeaning` contains `'রহমত'`.
  - `getAyatCategories(locale: en)` returns only English category names.
- `test/services/notification_service_test.dart` (new):
  - `AppText.of(Locale('bn')).notification_fajrTitle == 'ফজর নামাজ'`.
  - `AppText.of(Locale('en')).notification_fajrTitle == 'Fajr Prayer'`.

### 11.3 Widget tests (new or updated)
- `test/sahri_iftar_widget_test.dart`: wrap in `wrapWithLocale(locale: const Locale('en'))`; assertions unchanged in English, duplicated for Bengali.
- `test/widgets/calendar_selected_date_card_test.dart`: same.
- `test/services/widget_service_test.dart`: each test now passes `locale: const Locale('en')` to `computeWidgetPreviewData`. Add a mirror test for `const Locale('bn')` asserting Bengali strings.
- `test/widgets/language_dropdown_test.dart` (new): pumps `SettingsScreen` inside `wrapWithLocale`; verifies dropdown contains both items, tapping persists via mocked `SharedPreferences`.
- `test/screens/ebadat/ayat_tab_test.dart`, `dua_tab_test.dart`, `umrah_tab_test.dart` (new): verifies chip labels, error text, empty-state text in each locale.

### Acceptance gates for Phase 8
- `flutter test` — zero failures, zero skipped.
- Coverage for `locale_prefs.dart`, `app_locale_controller.dart`, `app_text.dart` is 100%.

---

## 12. Implementation Order (revised)

1. Phase 1 (Foundation) — one PR.
2. Phase 2 (Settings dropdown) — one PR. At this point the app already reacts to locale changes even though most UI is still hardcoded.
3. Phase 3 (`AppText`) — one PR.
4. Phase 4 (Models) — one PR per model (6 PRs). Ordering: `ebadat_topic`, `ayat`, `dua`, `umrah`, `monajat`, `worship_guide`.
5. Phase 5 (UI strings) — one PR per row in the §8 table (28 PRs). Nav + home + settings first so the app is immediately shippable.
6. Phase 6 (Ebadat data service) — one PR.
7. Phase 7 (English content) — one PR per data file (17 PRs). Prioritize files with the lowest prose volume first (attahiyatu, tayammum, tahiyyatul_masjid) to tighten the review loop.
8. Phase 8 (Tests) — tests ride in the same PR as the change they cover (D20). Final dedicated PR just adds the few cross-cutting tests that don't belong to any single change (e.g., bootstrap flow integration).

Parallelization: Phase 5 rows are independent of each other — multiple developers can work in parallel once Phase 3 is in.

---

## 13. Phase 9 — Verification Checklist (final gate)

Run before tagging the release.

1. `flutter pub get && flutter gen-l10n` — no errors.
2. `flutter analyze` — no warnings on the new files.
3. `flutter test` — zero failures.
4. `flutter build apk --debug` and `flutter build ipa --debug` — both succeed.
5. On a real Android device:
   - Cold install → UI is Bengali.
   - Toggle to English → every screen flips: Home, Ebadat (all three tabs and their detail screens), Calendar, Profile, Settings, Bookmarks, Admin.
   - Home-screen widget labels flip within 2 seconds.
   - Pending notifications are rescheduled with the new language (verify by scheduling a test prayer 1 minute ahead, switching language, and confirming the notification body reads in the new language).
   - Kill and relaunch — locale persists.
   - Toggle back to Bengali — no visual regressions vs. the pre-change build.
6. On an iOS device:
   - Same as above, plus confirm `CFBundleLocalizations` is recognized (Settings → Jamaat Time shows a language row under Preferred Language).
7. Numerals everywhere (times, countdowns, Hijri day) render in Western digits in both locales (D6).
8. Bengali text renders with Hind Siliguri (no tofu, correct conjuncts); English renders with Inter (D7).
9. Share/copy text for Ayat, Dua, Monajat, Umrah uses the active locale.
10. Search (Ebadat) returns results for a Bengali query in Bengali mode and for an English query in English mode (D19).
11. Arabic text is unchanged in both modes (D16).
12. Cold-start has no visible locale flicker (D15).

---

## 14. Rollback / Risk Mitigation

- `kLanguageSwitchEnabled = false` (D21) disables the dropdown and forces Bengali, without reverting any code. Ship a hotfix by flipping the flag if a production regression appears.
- All model English fields are nullable — if a data file is shipped partially-translated, the fallback is Bengali (no crash, no missing string).
- `scheduleAllNotifications` already cancels before scheduling (notification_service.dart:813), so language-change cannot produce duplicate notifications.
- Widget background isolate reads locale from SharedPreferences each invocation — no stale cache risk.
- Tests ride with their code changes (D20), so a revert of any PR restores a green suite.

---

## 15. Mapping — Audit Issues → This Plan

| Audit Issue | Resolved By |
|-------------|-------------|
| 1. Widget isolate unsafe singleton | D10, D11, §4.5 `LocalePrefs`, §8 (5.x) isolate-safe parameterization |
| 2. Ebadat category/search missed | D19, §8 rows 14-16, §9 |
| 3. Notification reschedule integration | D9, §5 (onSettingsChanged), §9 explicit reschedule step |
| 4. Stale file paths | §3.2 and §8 list every exact path including `topics/` disambiguation |
| 5. Test scope incomplete | §11 (§8 in outline) adds settings_service locale tests, dropdown test, tab tests, controller & prefs tests |
| 6. Locale bootstrap unspecified | D15, §4.8 (`await bootstrap()` before `runApp`, `ValueListenableBuilder` replaces manual stream subscription) |
| Additional A — Dropdown UX | D5 (two items, no null) |
| Additional B — Reference fields | §7 (per-file audit during Phase 4) |
| Additional C — Numerals | D6 (Western digits everywhere) |
| Additional D — Fonts | D7 (Hind Siliguri for bn, Inter for en) |
| Additional E — Widget stale label push | §8 (5.x) `WidgetService.forceRefresh()` on locale change |
| Additional F — Reschedule volume | §9 notes `compute` not required since scheduleAll already batches; monitor in Phase 9 |
| Additional G — Test coordination | D20, §12 (tests ride with code) |
| Additional H — fromJson nullability | D13, §7 pattern |
| Additional I — JSON schema version | D14, §10 JSON sample |

---

## 16. Out of Scope

- Urdu, Arabic, Hindi UI support (future work).
- User-submitted translations / crowd-sourcing pipeline.
- Translation of Firebase-driven remote content (jamaat timetable) — those come through the server as Bengali today; server-side work tracked separately.
- In-app translator tool.

---

*End of plan. This document is the sole source of truth for the language-selection feature. Update this file rather than `language.md` going forward.*
