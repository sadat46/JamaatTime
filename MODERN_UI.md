# Premium UI Upgrade — Home Screen

## Context
The Jamaat Time app currently has a functional but basic UI: a flat green theme, plain `Table` widgets with `TableBorder.all()` borders, a simple `LinearProgressIndicator`, and standard `BottomNavigationBar`. The goal is to elevate the Home Screen to a polished, premium feel — better cards, smoother layouts, refined typography, and subtle visual depth — without changing any functionality.

## What Changes (Home Screen Only)

### 1. Header Card Redesign
**File:** `lib/screens/home_screen.dart` (build method, lines ~880–1120)

Current: Plain `Card` with elevation 4, flat layout of location dropdown + date + clock + countdown + GPS row all stacked loosely.

Premium upgrade:
- Replace the single card with a **gradient hero header** — a Container with a subtle green gradient background (dark green → brand green) and rounded bottom corners
- Move the **mosque location** and **date/clock** into a clean two-row layout inside the header
- Make the **prayer countdown** the visual centerpiece: large countdown text with a **custom circular progress ring** (replacing the flat `LinearProgressIndicator`) showing time elapsed in the current prayer period
- Current prayer name displayed prominently above the countdown
- Subtle shadow/glow effect on the progress ring

### 2. Prayer Table → Prayer Cards
**File:** `lib/screens/home_screen.dart` (lines ~1157–1237)

Current: `Table` widget with `TableBorder.all()` — looks like a spreadsheet.

Premium upgrade:
- Replace the `Table` with a **Column of individual prayer row cards** — each prayer gets its own rounded card/tile
- Each card shows: prayer name (left), prayer time (center), jamaat time (right with mosque icon)
- **Active prayer** highlighted with a green accent border/left strip and subtle background glow
- Info rows (Sunrise, Dahwah-e-kubrah) styled differently — lighter, with an info icon
- Sahri/Iftar rows keep their amber styling but as cards
- Smooth spacing between cards (8px gap)

### 3. Forbidden Times → Styled Cards
**File:** `lib/widgets/forbidden_times_widget.dart`

Current: Another `Table` with red headers.

Premium upgrade:
- Replace table with **individual warning-styled cards** per forbidden window
- Each card: red-tinted glass background, time range, status badge
- Active window gets a pulsing red accent border

### 4. Countdown Widget Upgrade
**File:** `lib/widgets/prayer_countdown_widget.dart`

Current: Text + `LinearProgressIndicator` (flat green bar).

Premium upgrade:
- Replace `LinearProgressIndicator` with a **custom circular progress indicator** (using `CustomPainter` or `SizedBox` with `CircularProgressIndicator`) with rounded stroke caps
- Prayer name and countdown displayed inside the ring
- Gradient stroke color (light green → dark green)

### 5. Bottom Navigation Bar Polish
**File:** `lib/main.dart` (lines ~88–107)

Current: Default `BottomNavigationBar` with no customization.

Premium upgrade:
- Add `NavigationBar` (Material3) with pill-shaped indicator
- Slightly elevated with a subtle top border/shadow
- Icons get filled variants when selected

### 6. Section Headers
**File:** `lib/screens/home_screen.dart`

Current: Simple `Text` with hardcoded green color.

Premium upgrade:
- Add a subtle left accent bar (4px rounded green strip) before section titles
- Consistent section header widget reused for "Prayer Times", "Sahri & Iftar Times", "Forbidden Prayer Times"

## Files to Modify
1. `lib/screens/home_screen.dart` — Main layout restructure (header, prayer table → cards)
2. `lib/widgets/prayer_countdown_widget.dart` — Circular progress ring
3. `lib/widgets/forbidden_times_widget.dart` — Card-based layout
4. `lib/main.dart` — NavigationBar upgrade
5. `lib/themes/green_theme.dart` — Add card theme, navigation bar theme
6. `lib/themes/dark_theme.dart` — Matching dark mode updates
7. `lib/themes/white_theme.dart` — Matching white theme updates

## Existing Code to Reuse
- `_SahriIftarVisualSpec` pattern from `sahri_iftar_widget.dart` — excellent glass/gradient card design, reuse the approach for prayer cards
- `_InfoChip` widget from `sahri_iftar_widget.dart` — reuse for status badges
- `_AccentIconBadge` from `sahri_iftar_widget.dart` — reuse for prayer icons
- `AppConstants` brand colors from `lib/core/constants.dart`
- `PrayerRowData` / `PrayerRowType` enums already exist — just change rendering

## Implementation Order
1. Theme files (green, dark, white) — add card themes, navigation bar theme
2. Bottom nav bar in `main.dart` — quick Material3 `NavigationBar` swap
3. Prayer countdown widget — circular ring with gradient
4. Home screen header card → gradient hero header
5. Prayer table → card-based rows
6. Forbidden times → card-based layout
7. Section header widget

## Verification
- Run `flutter run` on Android/Windows and verify each screen visually
- Test light theme, dark theme, white theme
- Test with different prayer periods (Fajr, Dhuhr, Asr, etc.) to verify active row highlighting
- Test landscape orientation and tablet widths (600px breakpoint)
- Verify Sahri/Iftar widget still works (untouched, already premium)
- Verify forbidden times display correctly
- Pull-to-refresh still works
