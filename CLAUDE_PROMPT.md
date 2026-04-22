# Claude Opus CLI — Implementation Prompt

Implement Bengali/English language switching for the Jamaat Time Flutter app.

## Source of truth
`LANGUAGE_IMPLEMENTATION_PLAN_FINAL.md` — read it first, in full. It is authoritative. `language.md` (v1) is deprecated.

## Working rules
1. One phase per session. One row/file per commit.
2. Every commit is self-green: code + ARB keys + tests together.
3. Do not invent decisions — every choice is locked in plan §1 (D1–D21). If something is unclear, stop and ask.
4. Paths are exact (plan §3). Respect `ebadat/` vs `ebadat/topics/` split.
5. Never break Bengali — it is the default and the fallback for missing English content.
6. Before editing, run `flutter test` to confirm a green baseline. After editing, run `flutter gen-l10n`, `flutter analyze`, `flutter test`. Commit only when all three pass.

## Key invariants
- Runtime default = `bn`; template = `app_en.arb`; persisted value ∈ {`'bn'`,`'en'`} (no `null`).
- Numerals: Western digits in both locales (D6) — force `Locale('en')` for `DateFormat`/`NumberFormat`.
- Fonts: Hind Siliguri for `bn`, Inter for `en` (D7).
- Arabic text is never translated (D16).
- All `*English` model fields are nullable; locale getter falls back to Bengali (D13).
- JSON assets get `"schemaVersion": 2` (D14); old v1 files load without crash.
- UI uses `AppLocalizations.of(context)`. No-context code (`NotificationService`, `WidgetService`) uses `AppText.of(locale)` with locale from `AppLocaleController.instance.current` (UI) or `LocalePrefs.read()` (isolate).
- Widget background isolate reads locale from SharedPreferences; never from a singleton.
- Language change triggers `NotificationService.scheduleAllNotifications(...)` (auto-cancels stale) and `WidgetService.forceRefresh()`.

## Phase order (plan §12)
1. Phase 1 — Foundation (deps, `l10n.yaml`, ARB seed ~15 keys, `LocalePrefs`, `AppLocaleController`, `SettingsService.getLocale/setLocale`, `main.bootstrap`, iOS plist).
2. Phase 2 — Settings dropdown (two items, no null).
3. Phase 3 — `AppText` helper.
4. Phase 4 — Models bilingual (6 PRs: `ebadat_topic`, `ayat`, `dua`, `umrah`, `monajat`, `worship_guide`).
5. Phase 5 — UI strings (28 rows in plan §8 table; start with nav → home → settings).
6. Phase 6 — `EbadatDataService` locale-aware filter/search.
7. Phase 7 — English content in 14 Dart data files + 3 JSON assets.
8. Phase 8 — Cross-cutting tests cleanup.

## Stop conditions
Stop and report if: analyzer warnings appear on new files, any test goes red, a path in the plan does not exist on disk, or a decision in §1 conflicts with real code.

## Deliverable per session
A diff plus: (a) which plan row was completed, (b) `flutter test` output, (c) any new ARB keys added, (d) next row you propose to pick up.

Start with Phase 1. Confirm baseline is green, then proceed.
