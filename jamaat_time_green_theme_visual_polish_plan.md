# Jamaat Time Home Screen Green Theme Visual Polish Plan

## Objective

Polish the existing Jamaat Time home screen green theme to look premium, clean, high-contrast, and flagship-standard.

## Hard Rules

- Do **not** change any element layout.
- Do **not** add, remove, or reorder sections.
- Do **not** change business logic.
- Do **not** change prayer time calculation.
- Do **not** change countdown logic.
- Do **not** change notification logic.
- Do **not** refactor unrelated files.
- UI polish only.

Preserve the current screen structure:

- App header
- Summary/countdown card
- Prayer Times card
- Sahri & Iftar Times card
- Forbidden Prayer Times card
- Bottom navigation

---

## Phase 1 — Audit Only

### Task

Find the home screen UI files and theme/style files.

Search for:

- Home screen widget
- Prayer times section widget
- Sahri/Iftar section widget
- Forbidden prayer times section widget
- Bottom navigation widget
- `ThemeData`
- color constants
- text styles
- custom reusable card/section widgets

### Output before coding

Report:

1. Exact files to edit
2. Exact files not to touch
3. Whether colors/styles are centralized or scattered
4. Whether reusable UI constants already exist

Do not modify code in this phase.

---

## Phase 2 — Create Premium Green Design Tokens

### Task

Create or update centralized style tokens.

Prefer an existing theme/style file. If no central file exists, create one minimal file such as:

```text
lib/core/theme/app_theme_tokens.dart
```

Use these color tokens:

```dart
class AppColors {
  static const primaryGreen = Color(0xFF1F7A3E);
  static const primaryDark = Color(0xFF155B2D);
  static const primarySoft = Color(0xFFEAF5EE);
  static const primarySoft2 = Color(0xFFF4FAF6);

  static const pageBackground = Color(0xFFF3F8F4);
  static const cardBackground = Color(0xFFFFFFFF);
  static const sectionTint = Color(0xFFEEF6F0);

  static const textPrimary = Color(0xFF17211B);
  static const textSecondary = Color(0xFF5F6F64);
  static const textMuted = Color(0xFF88958C);

  static const borderLight = Color(0xFFDCE8DF);
  static const borderActive = Color(0xFFA8D5B4);

  static const activeFill = Color(0xFFEDF7EF);
  static const activeAccent = Color(0xFF3E9A52);

  static const warningSoft = Color(0xFFFFF7F1);
  static const warningAccent = Color(0xFFA8642A);
}
```

Add radius and shadow tokens:

```dart
class AppRadius {
  static const double card = 22;
  static const double row = 16;
  static const double chip = 999;
}

class AppShadows {
  static List<BoxShadow> softCard = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  static List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];
}
```

### Rules

- Do not use heavy blur shadows everywhere.
- Keep shadows subtle.
- Avoid many random green shades.
- Use design tokens instead of scattered hardcoded colors.

---

## Phase 3 — Typography Polish

### Task

Update text styling only, without moving widgets.

Use consistent hierarchy:

```text
App title:        26–30px, FontWeight.w600/w700
Section title:   20–22px, FontWeight.w700
Prayer names:    18–19px, FontWeight.w600
Main times:      18–22px, FontWeight.w600
Countdown:       30–42px depending section
Secondary text:  13–15px, FontWeight.w400/w500
Muted helper:    12–13px, FontWeight.w400
```

### Color rules

- Primary information: `AppColors.textPrimary`
- Important green numbers: `AppColors.primaryGreen`
- Secondary information: `AppColors.textSecondary`
- Helper/meta information: `AppColors.textMuted`
- Section titles: `AppColors.primaryDark`

Do not make all text green. Only important values should use green.

---

## Phase 4 — Page Background

### Task

Change the main home screen background to:

```dart
AppColors.pageBackground
```

Avoid pure white full-page background.

### Expected result

- Cards become more distinct.
- Green theme feels softer and more premium.

---

## Phase 5 — Global Card Polish

### Task

Apply consistent decoration to all major section cards.

Use:

```dart
BoxDecoration(
  color: AppColors.cardBackground,
  borderRadius: BorderRadius.circular(AppRadius.card),
  border: Border.all(color: AppColors.borderLight, width: 1),
  boxShadow: AppShadows.softCard,
)
```

Apply to:

- Top summary/countdown card
- Prayer Times card
- Sahri & Iftar card
- Forbidden Prayer Times card

Do not change their layout or child order.

---

## Phase 6 — Header / App Bar Polish

### Task

Polish the green header visually.

Keep:

- Same title
- Same bell icon
- Same location of elements

Improve:

- Use deeper green: `AppColors.primaryGreen` or gradient from `AppColors.primaryDark` to `AppColors.primaryGreen`
- Title text should be clean white with better weight
- Bell icon should remain visible and crisp
- Remove/debug ribbon only if this is production-build related; do not hide debug by UI hack

Suggested header background:

```dart
LinearGradient(
  colors: [
    AppColors.primaryDark,
    AppColors.primaryGreen,
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```

---

## Phase 7 — Prayer Times Section Polish

### Header

- Keep “Prayer Times” position.
- Left accent bar:
  - Width: 5–6
  - Rounded
  - Color: `AppColors.primaryGreen`
- Title:
  - `AppColors.primaryDark`
  - Bold
- “Last updated”:
  - `AppColors.textMuted`
  - 13–14px
  - italic optional

### Prayer rows

Apply row style:

```dart
BoxDecoration(
  color: AppColors.cardBackground,
  borderRadius: BorderRadius.circular(AppRadius.row),
  border: Border.all(color: AppColors.borderLight),
)
```

For inactive rows:

- Prayer name: `AppColors.textPrimary`
- Prayer time: `AppColors.textPrimary`
- Jamaat time: `AppColors.primaryGreen`
- Secondary/sunrise: `AppColors.textSecondary`

For active/current prayer row:

```dart
BoxDecoration(
  color: AppColors.activeFill,
  borderRadius: BorderRadius.circular(AppRadius.row),
  border: Border.all(color: AppColors.borderActive),
)
```

Also keep the existing left active strip, but polish:

- Color: `AppColors.activeAccent`
- Fully rounded
- Width: 5–6

Do not change row order or column alignment.

---

## Phase 8 — Sahri & Iftar Section Polish

### Section card

Use the same major card decoration.

### Inner Sahri/Iftar cards

Keep the same layout.

Improve:

- Stronger white card surface
- Softer green gradient
- Less washed-out text
- Main countdown should be highly readable

Suggested inner card background:

```dart
LinearGradient(
  colors: [
    Color(0xFFFFFFFF),
    Color(0xFFF3FAF5),
    Color(0xFFE3F4E8),
  ],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
)
```

Text rules:

- Title: `AppColors.textPrimary`, 18–20px, semibold
- Countdown: `AppColors.primaryDark`, 30–36px, bold/semibold
- Ends/Begins text: `AppColors.textSecondary`
- Helper text: `AppColors.textSecondary`

Icon badge:

- Keep existing icons.
- Use soft circular badge.
- Avoid strong glow.
- Use very subtle shadow only.

---

## Phase 9 — Forbidden Prayer Times Polish

### Outer card

Use warm warning tint but keep it premium.

Suggested:

```dart
color: AppColors.warningSoft
```

With subtle border:

```dart
Border.all(color: Color(0xFFF0DDD0))
```

### Header

- Warning icon: `AppColors.warningAccent`
- Title: `AppColors.textPrimary`
- “3 windows” chip:
  - Soft filled background
  - Rounded pill
  - Subtle border
  - Secondary text color

### Rows

Keep the same layout.

Row style:

- White background
- Subtle border
- Rounded corners
- No heavy shadows

Text:

- Restriction name: `AppColors.textPrimary`, semibold
- Time range: `AppColors.textSecondary`
- Duration/Next chip: muted but readable

---

## Phase 10 — Bottom Navigation Polish

Keep the same layout and tabs.

Improve:

- White surface
- Soft top border or subtle shadow
- Active tab green pill background
- Active icon: `AppColors.primaryGreen`
- Active label: `AppColors.primaryGreen`, medium/semibold
- Inactive icons: darker grey, not too faded
- Inactive labels: `AppColors.textSecondary`

Suggested inactive color:

```dart
Color(0xFF6B746D)
```

---

## Phase 11 — Icon Polish

Do not replace logic or icon meaning.

Only polish:

- Icon container color
- Icon stroke/color consistency
- Icon size consistency

Suggested prayer icon badge colors:

```text
Fajr:     #EAF4FF
Sunrise:  #FFF4DA
Dhuhr:    #FFF0E0
Asr:      #E7F6F2
Maghrib:  #F8EFE6
Isha:     #EFEFFF
```

Rules:

- Keep icon circles soft.
- Avoid saturated icon backgrounds.
- Keep icon color readable.

---

## Phase 12 — Spacing Consistency

No layout change, but normalize existing padding.

Rules:

- Major card horizontal padding: 16–20
- Major card vertical padding: 16–20
- Row vertical spacing: 10–12
- Section gap: 16–20
- Icon-to-text spacing: consistent
- Avoid changing the position/order of widgets.

Only adjust padding if it improves consistency and does not alter layout structure.

---

## Phase 13 — Final QA Checklist

Test on:

- Small phone
- Medium phone
- Large phone
- Bangla text visible
- Long location text
- 12-hour/24-hour time if supported
- Current prayer active row
- Sunrise row without Jamaat time
- Dark system mode if app forces light theme

Acceptance criteria:

- [ ] Cards are clearly distinct from background.
- [ ] Text is easier to read than before.
- [ ] Green theme feels richer, not flat.
- [ ] Active prayer row is clear but not harsh.
- [ ] Sahri/Iftar cards are readable and less washed out.
- [ ] Forbidden prayer card is warm and premium, not alarming.
- [ ] Bottom navigation matches the overall theme.
- [ ] No overflow introduced.
- [ ] No layout structure changed.
- [ ] No business logic changed.

---

## Files Scope Rule

Only edit files directly related to:

- Home screen UI
- Home screen child widgets
- App theme/colors/text styles
- Shared card/section UI components used by this screen

Do not edit:

- Prayer calculation services
- Notification services
- Firebase/Supabase logic
- Location services
- Widget/background scheduler
- Admin logic
- Authentication logic

---

## Final Deliverable

After implementation, report:

1. Files changed
2. Visual tokens added/updated
3. Sections polished
4. Confirmation that layout and logic were not changed
5. Screenshots or build result if available
