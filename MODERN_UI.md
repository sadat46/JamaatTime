# Premium UI Upgrade — Home Screen (Revised)

## Context

The Jamaat Time app has a functional but visually basic Home Screen: flat green cards,
spreadsheet-style Table widgets, a horizontal LinearProgressIndicator, and a default
BottomNavigationBar. The goal is to elevate the Home Screen to a premium, polished feel
without changing any prayer/jamaat calculation logic or navigation contracts.

This spec is revised from the original after a codebase audit that found 5 issues:

1. **Scope mismatch** — original plan included `main.dart` nav bar and dark/white theme
   files, which are app-wide changes. This revision limits scope to Home Screen only.
2. **Dead code risk** — Dark/white themes are not wired in the app (`main.dart` only sets
   `greenTheme`). Modifying them would be dead code. Excluded from this revision.
3. **Private widget reuse** — `_InfoChip` and `_AccentIconBadge` in `sahri_iftar_widget.dart`
   use Dart's `_` prefix (library-private). They cannot be imported cross-file without
   extraction into a shared public file first.
4. **Duplicate section headers** — `SahriIftarWidget` (`line 307`) and
   `ForbiddenTimesWidget` (`line 34`) already render their own section titles. Adding
   Home-level `SectionHeader`s without removing the internal ones would create duplicates.
5. **Animation in StatelessWidget** — `ForbiddenTimesWidget` is a `StatelessWidget`.
   A pulsing animation and periodic `isActive` refresh both require converting it to
   `StatefulWidget` with a `SingleTickerProviderStateMixin`.

---

## Scope

**In scope:** Home Screen visual upgrade only.

**Out of scope:** `main.dart` BottomNavigationBar, `dark_theme.dart`, `white_theme.dart`,
all prayer/jamaat calculation logic, notification service, Firebase, routing, other screens.

---

## What Changes

### 1. New Shared UI Primitives File

**File:** `lib/widgets/shared_ui_widgets.dart` *(new)*

A small shared widgets file exporting 3 public widgets that other widgets can import:

**`AccentIconBadge`**
- Extracted and made public from `_AccentIconBadge` in `sahri_iftar_widget.dart:1044`
- Circular badge with icon, glow box-shadow, semi-transparent tint background
- Props: `icon`, `accent`, `tint`, `size`, `iconSize`

**`InfoChip`**
- Extracted and made public from `_InfoChip` in `sahri_iftar_widget.dart:1082`
- Rounded pill with icon + label, glass-effect border
- Props: `icon`, `label`, `accent`, `textColor`, `fill`, `padding`, `iconSize`, `textStyle`

**`SectionHeader`**
- New widget: 4 px rounded green left accent strip + bold title text
- Props: `title` (String)
- Used at Home level for "Prayer Times", "Sahri & Iftar Times", "Forbidden Prayer Times"

After creating this file, update `sahri_iftar_widget.dart` to import and use the public
`AccentIconBadge` and `InfoChip` instead of the private `_` versions (behavior unchanged).

---

### 2. Prayer Countdown Widget — Circular Ring

**File:** `lib/widgets/prayer_countdown_widget.dart`

Current: `Text` + `LinearProgressIndicator` (flat green bar, line 292).

Change:
- Replace `LinearProgressIndicator` with a `CustomPainter`-based circular progress ring
- Gradient stroke: `AppConstants.brandGreenLight` → `AppConstants.brandGreenDark`, rounded caps
- Prayer name displayed above the ring center; HH:MM:SS countdown inside the ring
- Keep all existing logic untouched: one-second timer, progress calculation,
  special Sunrise / Dahwah-e-kubrah text states

---

### 3. Home Screen Header — Gradient Hero

**File:** `lib/screens/home_screen.dart` (lines ~880–1120)

Current: Standard `Card(elevation: 4)` with flat layout.

Change:
- Replace with a `Container` using a subtle green gradient background
  (`AppConstants.brandGreenDark` → `AppConstants.brandGreen`) and rounded bottom corners
- Inside: mosque location + date in a clean two-row layout
- `PrayerCountdownWidget` as the visual centerpiece (upgraded in step 2)
- GPS status row preserved at the bottom of the header
- All existing dropdown/location logic, pull-to-refresh, and selected-date behavior unchanged

---

### 4. Prayer Table → Card Rows

**File:** `lib/screens/home_screen.dart` (lines ~1157–1238)

Current: `Table` with `TableBorder.all()` — spreadsheet look.

Change:
- Replace `Table` block with a `Column` of card rows driven by existing `_prayerTableData`
- Replace plain `Text('Prayer Times')` label (line 1128) with
  `SectionHeader(title: 'Prayer Times')`
- Row style rules:
  - **Regular prayer rows**: rounded card, name left / time center / jamaat right with mosque icon
  - **Info rows** (Sunrise, Dahwah-e-kubrah): lighter background, info icon, italic, no jamaat col
  - **Active row** (current prayer): 4 px green left accent strip + subtle green tint background
  - **Sahri/Iftar rows**: amber accent, consistent with existing amber styling
- 8 px gap between cards
- Same row order, same data source (`_prayerTableData`), same active-row highlight logic

---

### 5. SahriIftarWidget — Remove Internal Title

**File:** `lib/widgets/sahri_iftar_widget.dart` (lines 307–315)

Current: Widget renders its own `'Sahri & Iftar Times'` title text internally.

Change:
- Remove (or gate behind a `showTitle: bool` parameter, defaulting `false`) the internal title
- Home screen wraps it with `SectionHeader(title: 'Sahri & Iftar Times')`
- No other changes — all countdown, grace period, animation, fullscreen behavior preserved

---

### 6. Forbidden Times — Card Layout + Pulse Animation

**File:** `lib/widgets/forbidden_times_widget.dart`

Current: `StatelessWidget`, `Table` with red headers, `isActive` read once at build time.

Changes:
1. Convert to `StatefulWidget` with `SingleTickerProviderStateMixin`
2. Add a 1-minute periodic `Timer` → `setState` so `isActive` stays current after build
3. Replace `Table` with a `Column` of individual warning cards per forbidden window:
   - Red-tinted glass background per card
   - Window name, time range, `InfoChip` for "Makruh" status badge
   - Active window: stronger red accent + pulsing red border (via `AnimationController`)
4. Remove internal `'Forbidden Prayer Times'` title (lines 34–40)
   — Home screen wraps it with `SectionHeader(title: 'Forbidden Prayer Times')`
5. All forbidden window calculations from `PrayerCalculationService` unchanged

---

## Files to Modify

| # | File | Change |
|---|------|--------|
| 1 | `lib/widgets/shared_ui_widgets.dart` | **New** — `AccentIconBadge`, `InfoChip`, `SectionHeader` |
| 2 | `lib/widgets/prayer_countdown_widget.dart` | Circular ring replaces `LinearProgressIndicator` |
| 3 | `lib/screens/home_screen.dart` | Gradient header + table → cards + `SectionHeader`s |
| 4 | `lib/widgets/sahri_iftar_widget.dart` | Remove internal title; adopt public shared widgets |
| 5 | `lib/widgets/forbidden_times_widget.dart` | `StatefulWidget` + cards + pulse animation |

**Not touched:** `lib/main.dart`, `lib/themes/*.dart`, `lib/core/constants.dart`,
all service / model / calculation files.

---

## Existing Code to Reuse

| Widget / Class | Location | Purpose |
|---|---|---|
| `_AccentIconBadge` | `sahri_iftar_widget.dart:1044` | Extract → public `AccentIconBadge` |
| `_InfoChip` | `sahri_iftar_widget.dart:1082` | Extract → public `InfoChip` |
| `_SahriIftarVisualSpec` | `sahri_iftar_widget.dart:99` | Reference for glass/gradient pattern |
| `PrayerRowData` / `PrayerRowType` | `home_screen.dart:1–50` | Data model for card rows |
| `_prayerTableData` | `home_screen.dart` | Data source, used as-is |
| `_getRowDecoration` | `home_screen.dart` | Active-row logic reference |
| `AppConstants.brandGreen/Dark/Light` | `lib/core/constants.dart` | Gradient colors |
| `PrayerCalculationService.calculateForbiddenWindows` | service file | Unchanged |

---

## Implementation Order

1. `shared_ui_widgets.dart` — shared primitives first (others depend on it)
2. `prayer_countdown_widget.dart` — circular ring
3. `home_screen.dart` — gradient hero header
4. `home_screen.dart` — prayer table → card rows + `SectionHeader`s
5. `sahri_iftar_widget.dart` — remove internal title, adopt public shared widgets
6. `forbidden_times_widget.dart` — `StatefulWidget`, card layout, pulse animation

---

## What Does NOT Change

- All prayer time and jamaat time calculations
- Pull-to-refresh behavior
- GPS mode / location selection / city dropdown
- Selected-date logic
- Sahri/Iftar grace period, forward counter, pulse animation, fullscreen mode
- `BottomNavigationBar` in `main.dart`
- Dark and white theme files
- Notification, Firebase, bookmark services

---

## Verification

1. `flutter run` on Android — Home screen renders without overflow or regressions
2. Countdown ring updates every second and matches prior textual countdown values
3. Active prayer row highlight matches previous `_getRowDecoration` logic for all periods
4. Sunrise and Dahwah rows styled as info rows (not regular jamaat rows)
5. Jamaat loading spinner and error text still appear in the prayer section
6. GPS status message and location row still visible in header
7. Forbidden cards: correct time ranges; active window toggles correctly over time
8. Pull-to-refresh still triggers data reload
9. Landscape and ≥600 px width layouts stay readable without overflow
10. Sahri/Iftar: countdown, grace period, fullscreen tap all still work
11. Only green theme tested (dark/white are not wired in the app)
