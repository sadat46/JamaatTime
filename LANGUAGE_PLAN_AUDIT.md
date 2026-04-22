# Audit of `language.md` Implementation Plan

**Date:** 2026-04-17
**Scope:** Validation of the Bangla/English localization plan for the Jamaat Time Flutter app, and confirmation/refinement of the AI agent's review.

**Verdict:** The plan is a strong foundation, but it **needs revision before implementation**. All six issues raised by the AI agent are valid or partially valid, and I have identified several additional gaps.

---

## 1. Validation of the AI Agent's Six Findings

### Issue 1 (High) — Locale source unsafe for widget updates: **CONFIRMED**

The plan proposes a `LocaleProvider` singleton (language.md:59-62, language.md:171) for non-context services including `WidgetService`. However, `lib/services/widget_service.dart` contains a top-level `backgroundCallback` annotated `@pragma('vm:entry-point')` (line 22-23). Home-widget refresh triggers a **separate Dart isolate** that has its own memory — a UI singleton cannot be shared across isolates.

Concrete hardcoded English strings in the background path:

- Lines 263-265: `remainingLabel = currentPeriod == 'Sunrise' ? 'Coming Dhuhr' : '$currentPeriod Time Remaining'`
- Line 321: `'$jamaatPrayerName Jamaat in'`
- Line 380: `'Jamaat N/A'`
- Line 385: `'Jamaat is Over'`

None of `computeWidgetPreviewData`, `_computeJamaatWidgetState`, or `updateWidgetData` accept a locale parameter. The plan must specify that the background callback reads locale directly from `SharedPreferences` (e.g. `_localeKey = 'app_locale'`) and that `computeWidgetPreviewData`/helpers take a `locale` argument. Using a plain Dart singleton is unsafe across isolates.

**Required fix:** change Phase 1.5 to "Locale helper that reads from SharedPreferences on demand in isolates" and add an explicit `locale` parameter to the widget preview helpers (plus update the `widget_service_test.dart` tests accordingly).

### Issue 2 (High) — Ebadat category/search missed: **CONFIRMED**

`lib/services/ebadat_data_service.dart` filters and searches only on Bengali fields:

- `getAyatCategories`, `getDuaCategories` (lines 109-121): read `ayat.category`/`dua.category` which are Bengali strings in the JSON.
- `searchAyats` (lines 124-138): matches on `titleBangla`, `surahName`, `banglaTransliteration`, `banglaMeaning`, `category`.
- `searchDuas` (lines 140-153): same pattern, Bengali-only fields.

The three Ebadat tab screens also carry user-facing Bengali hardcoded strings that Phase 5's table does not cover:

- `ayat_tab.dart:52` — `'ডেটা লোড করতে ব্যর্থ হয়েছে। পুনরায় চেষ্টা করুন।'`
- `ayat_tab.dart:114` — `'পুনরায় চেষ্টা করুন'`
- `ayat_tab.dart:140-141` — `'এই ক্যাটাগরিতে কোনো আয়াত নেই'` / `'কোনো আয়াত পাওয়া যায়নি'`
- `ayat_tab.dart:153` — `'ফিল্টার মুছে ফেলুন'`
- `ayat_tab.dart:176` — `'সব'` (the "All" filter chip)
- Equivalent strings in `dua_tab.dart` and `umrah_tab.dart`

Phase 3 adds `categoryEnglish` to the models but Phase 5/6 do not thread that through the filter/search/chip UI. Without updating `EbadatDataService` to locale-aware filtering/searching, English mode will show Bengali category chips and search will silently fail against English queries.

**Required fix:** add a row to the Phase 5 table for `lib/screens/ebadat/tabs/ayat_tab.dart`, `dua_tab.dart`, `umrah_tab.dart`, and extend Phase 6 to rewrite `getAyatCategories`, `getDuaCategories`, `searchAyats`, `searchDuas` to accept a `locale` parameter (or accept both Bengali and English category values).

### Issue 3 (Medium) — Notification reschedule integration unclear: **CONFIRMED**

The plan (language.md:12) says "On language change, cancel and reschedule all pending notifications," but the existing scheduling logic in `home_screen.dart:377-403` is gated by:

- `if (jamaatTimes == null) return;`
- `if (selectedDateOnly != today) return;` (today-only)
- `if (!_notificationsScheduled || _lastScheduledDate.isBefore(today))` (once-per-day)

There is already a proven pattern at `home_screen.dart:405-418` (`_handleNotificationSettingsChange`) that resets `_notificationsScheduled = false` and calls `_scheduleNotificationsIfNeeded()` when the user changes notification sound. The plan should explicitly:

1. Subscribe to `onSettingsChanged` so locale changes reach `HomeScreen`.
2. Call a new `_handleLocaleChange` that mirrors `_handleNotificationSettingsChange` (reset the flag, then `_scheduleNotificationsIfNeeded`).
3. State what happens when locale changes while the selected date is not today (today-only gate will skip — likely acceptable, but should be documented).
4. Confirm whether `scheduleAllNotifications` itself will cancel stale ones, or if an explicit cancel is needed for the stale-language text already shown as a pending notification.

### Issue 4 (Medium) — Stale file paths: **PARTIALLY CONFIRMED**

Phase 5 row at line 184 names `ayat_detail_screen.dart`, `dua_detail_screen.dart`, `umrah_detail_screen.dart`, `monajat_detail_screen.dart`, `monajat_list_screen.dart`. Actual locations are split:

- `lib/screens/ebadat/ayat_detail_screen.dart` — NOT under `topics/` (plan is correct here)
- `lib/screens/ebadat/dua_detail_screen.dart` — NOT under `topics/` (plan correct)
- `lib/screens/ebadat/umrah_detail_screen.dart` — NOT under `topics/` (plan correct)
- `lib/screens/ebadat/topics/monajat_detail_screen.dart` — IS under `topics/` (plan omits the subdirectory)
- `lib/screens/ebadat/topics/monajat_list_screen.dart` — IS under `topics/` (plan omits)

Additionally, `worship_guide_screen.dart` (referenced in Phase 5 row 173 and Phase 6) is actually at `lib/screens/ebadat/topics/worship_guide_screen.dart`, and all list screens (`ayat_list_screen.dart`, `dua_list_screen.dart`, `umrah_list_screen.dart`, `monajat_list_screen.dart`) live under `topics/` per `ebadat_screen.dart:5-11`.

**Required fix:** rewrite the Phase 5/6 file lists with full paths (`ebadat/...` vs `ebadat/topics/...`) so implementers do not create duplicate files or misroute imports.

### Issue 5 (Medium) — Test scope incomplete: **CONFIRMED**

`test/services/settings_service_test.dart` (lines 14-30 shown) covers only hijri offset and notification sound migration. It has no locale coverage. Plan line 232 marks this file "Safe (no changes needed)", which is wrong because Phase 1.4 introduces `getLocale()`/`setLocale(String?)` and a new `_controller.add(null)` broadcast. These must have:

- Default-value tests (`getLocale()` returns `null` when unset).
- Round-trip tests (`setLocale('en')` then `getLocale()` returns `'en'`).
- Clearing tests (`setLocale(null)` clears the key).
- Stream-emission test: `onSettingsChanged` fires after `setLocale`.

Also missing from Phase 7: (a) widget test for the new language dropdown in `settings_screen.dart`; (b) unit test for the `LocaleProvider`/SharedPreferences-based locale helper used in isolates; (c) widget tests for `ayat_tab` / `dua_tab` / `umrah_tab` filter-chip localization (because those screens were missed entirely in Phase 5 — see Issue 2).

### Issue 6 (Medium) — Locale bootstrap details need tightening: **CONFIRMED**

`lib/main.dart:61` is `class MyApp extends StatelessWidget`. The plan (1.6) says "convert MyApp to StatefulWidget, subscribe in initState," but does not specify:

- **Initial load is async.** `SettingsService().getLocale()` returns a `Future<String?>`. The first frame will render before the saved locale is known unless the plan uses a `FutureBuilder` or a pre-`runApp` `await` in `main()` (similar to the existing `HomeWidget.registerInteractivityCallback` setup at line 55-58). Without this, users briefly see Bengali (the default) even when they have saved English — a visible flicker.
- **Subscription disposal.** `dispose()` must cancel the `StreamSubscription` from `onSettingsChanged` or the app will leak on hot restart and fire into disposed state.
- **Rebuild scope.** Changing locale should trigger `MaterialApp` rebuild (so `localizationsDelegates` re-resolve), but should not stomp `Navigator` state.
- **LocaleProvider sync.** The plan says "Update LocaleProvider whenever locale changes" — needs to specify ordering: persist-first then update-singleton-then-notify, so any listener reading from the singleton sees the new value.

**Recommended fix:** either (a) `await settings.getLocale()` in `main()` before `runApp`, or (b) have `MyApp` build a `FutureBuilder<String?>` with a splash screen until the first value resolves; explicitly document both `dispose` cancellation and the ordering of persistence→singleton→notify.

---

## 2. Additional Issues Not Raised by the AI Agent

### A. Dropdown design creates a persistence ambiguity (Phase 2.1)

The language dropdown (language.md:87-91) offers three items:

- `null → 'বাংলা (Default)'`
- `'en' → 'English'`
- `'bn' → 'বাংলা'`

This exposes internal nullability to users. The "Default" label and the "বাংলা" label both display Bengali UI identically; users cannot tell them apart and cannot tell which one is "saved". Recommend collapsing to two options (Bangla / English) and treating Bangla as persisted value `'bn'`, reserving `null` only for "never set" during first-launch detection.

### B. Phase 3.1 Reference fields may not be purely language-neutral

Plan line 110 asserts `Reference.source/citation/fullText` are "language-neutral academic citations." In Islamic content files it is common for `fullText` to carry a Bengali gloss of hadith or tafsir. Grep `lib/data/*.dart` for `Reference(` calls and check whether `fullText` contains any Bengali script before locking this decision.

### C. Bengali numeral policy is not decided

`intl: ^0.20.2` is already in `pubspec.yaml:43`. In Bengali locale, `DateFormat('hh:mm a').format(...)` and `NumberFormat`/`DateFormat` may emit Bengali digits (০১২...). Prayer times, countdown, Hijri date in the home screen and widget may render in Bengali digits in `bn` mode. This is cosmetic but breaks existing tests and some users expect English digits even in Bengali UI (common in Bangladesh apps). The plan should state the decision: "always Western digits" (pass `en` locale to `DateFormat`) or "follow active locale".

### D. Fonts and text shaping not discussed

The app uses `google_fonts: ^6.2.1`. Bengali script requires a Bengali-capable font (e.g. Hind Siliguri, Noto Sans Bengali, SolaimanLipi). If the current default font is Latin-only, Bengali strings fall back to the system font — which on Windows/iOS may render as tofu boxes or unaesthetic. Phase 1 should lock the Bengali fallback font and whether English mode keeps the same family.

### E. Home-widget background callback is a second consumer of locale persistence

Closely tied to Issue 1: the Kotlin/Java side of `PrayerWidgetProvider` may read the saved labels from `HomeWidget.saveWidgetData`, but if the widget refresh runs in the background isolate before the user has opened the app after a locale change, the stale strings persist. Plan must document that `setLocale` triggers an immediate `WidgetService.updateWidgetData` re-push.

### F. Notification cancel-and-reschedule volume

`scheduleAllNotifications` schedules ~10-12 notifications daily (5 prayer × 2 reminders each, + jamaat notifications). A language change on the settings screen will cancel and reschedule all of them synchronously on the UI thread. Plan should note whether to run this off the main isolate (using `compute`) to avoid a frame drop when the user toggles language. It is likely fine, but should be called out.

### G. Test coordination risk

Phase 7 is scheduled last, but Phase 1.5 introduces `LocaleProvider` and Phase 5 replaces hardcoded strings in `widget_service.dart`. As soon as the `bn` default is live, `test/services/widget_service_test.dart` assertions (`'Fajr Time Remaining'`, `'Coming Dhuhr'`, etc.) will fail. The implementation order (language.md:239-247) needs a caveat that the tests must be updated **in the same commit** as the string changes, not deferred to Phase 7.

### H. Phase 3 fromJson/toJson risk

Phase 3.3 says "update `fromJson`/`toJson`" for `AyatModel`, `DuaModel`, `UmrahModel`. The JSON assets in `assets/data/` currently hold only Bengali fields. If `fromJson` starts requiring English fields (non-nullable), loading existing assets will throw. The plan should specify: English fields are nullable in the model and `fromJson` tolerates their absence, with content added to JSON in Phase 4. Otherwise the app will crash between Phase 3 and Phase 4.

### I. Phase 4's JSON asset migration strategy is silent on schema version

Updating `assets/data/ayats.json`, `duas.json`, `umrah.json` with English parallel fields is ~1000+ strings. If partial edits are committed, the schema is inconsistent. Recommend: add a top-level `"schemaVersion": 2` and make `fromJson` read it, so partial data can be tolerated and migration can run in stages.

---

## 3. Items the Agent Correctly Said Were OK

Verified from actual codebase:

- `pubspec.yaml` has no `flutter_localizations` and no `generate: true` under `flutter:` — correct.
- No `l10n.yaml` in repo root.
- No `.arb` files anywhere in the tree.
- `MaterialApp` in `main.dart:66-70` has no `localizationsDelegates`, `supportedLocales`, or `locale` set.

The foundation assumptions in the plan are therefore accurate. The revisions required are about **completeness and correctness of the change-set**, not about the strategy (ARB + hybrid bilingual-models) itself, which is sound.

---

## 4. Recommended Revisions Before Implementation

Priority order:

1. **Fix widget isolate locale access** (Issue 1) — replace the singleton strategy in widget code with SharedPreferences reads, and thread `locale` through `computeWidgetPreviewData`/`_computeJamaatWidgetState`.
2. **Add Ebadat tabs + service to Phase 5/6** (Issue 2) — include `ayat_tab.dart`, `dua_tab.dart`, `umrah_tab.dart`, and update `ebadat_data_service.dart` filter/search to be locale-aware.
3. **Define locale-change → notification reschedule integration** (Issue 3) — mirror the `_handleNotificationSettingsChange` pattern.
4. **Fix file paths in Phase 5/6 tables** (Issue 4) — distinguish `ebadat/` vs `ebadat/topics/`.
5. **Expand Phase 7** (Issue 5) — add locale tests to `settings_service_test.dart`, widget tests for the language dropdown, and widget tests for the Ebadat tabs.
6. **Specify bootstrap semantics** (Issue 6) — decide await-in-main vs FutureBuilder, document disposal and ordering.
7. **Resolve dropdown UX ambiguity** (Additional A) — two options rather than three.
8. **Decide numeral + font policy** (Additional C, D) — lock before Phase 1 ends.
9. **Guard nullability in models** (Additional H) — keep English fields optional across Phase 3→4 transition.
10. **Note test/code coupling in implementation order** (Additional G).

Once these revisions are folded in, the plan is implementable.

---

*Note: I reviewed and analyzed the existing code to verify each claim. I did not modify any code files as part of this audit — this document is a report only.*
