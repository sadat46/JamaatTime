# Jamaat Time Home Screen - Main Card Premium Polish Plan

## Objective

Polish only the home screen top green stage and main countdown card so the area feels clearer, cleaner, more premium, and easier to read.

This is a visual-polish plan only. Do not implement it while updating this file.

## Verified Current Implementation

- Home stage, app title, bell action, main countdown card, and right-side info block are built in `lib/screens/home_screen.dart`.
- The countdown ring is a custom painter in `lib/widgets/prayer_countdown_widget.dart`.
- Shared design constants currently live in `lib/core/app_theme_tokens.dart`.
- The stage and main card already use different gradients, but the colors are still partly hardcoded inside widgets.
- The current card layout is a two-column structure: countdown ring on the left, location/time/date/location metadata on the right.

## Non-Negotiable Rules

- Do not change the element layout.
- Do not move the countdown ring.
- Do not move the right-side location, time, date, Hijri date, Bangla date, or place-name block.
- Do not change card structure, card order, navigation, notification behavior, prayer logic, countdown logic, location logic, or loading/error behavior.
- Do not edit prayer services, notification services, location services, Firebase/Supabase logic, Android widget logic, admin screens, auth logic, or unrelated widgets.
- Only polish colors, gradients, typography, opacity, border, shadow, icon color, ring style, and very small spacing values inside existing containers.

## Premium Visual Direction

Use a clean emerald hierarchy:

```text
Stage/appbar: darkest emerald
Main card: slightly lighter rich emerald
Foreground: clear white with opacity hierarchy
Ring: white or mint-white progress with soft translucent track
Border: subtle translucent white line
Shadow: soft ambient depth, not glow
```

The main card must stay visually separate from the stage but must not become heavier or darker than the stage.

Avoid:

- Neon green
- Harsh black shadow
- Busy texture or pattern
- Glossy/artificial shine
- Multiple competing overlays
- All text using the same full-white opacity

## Design Tokens

Add home-hero-specific tokens to `lib/core/app_theme_tokens.dart` instead of scattering new hardcoded values through widgets.

Recommended tokens:

```dart
class HomeHeroColors {
  static const stageTop = Color(0xFF073F22);
  static const stageBottom = Color(0xFF0B5A31);

  static const cardTopLeft = Color(0xFF126B38);
  static const cardBottomRight = Color(0xFF1F7A3E);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xCCFFFFFF);
  static const textMuted = Color(0xA6FFFFFF);

  static const ringTrack = Color(0x33FFFFFF);
  static const ringProgress = Color(0xFFF7FFF9);

  static const cardBorder = Color(0x33FFFFFF);
  static const divider = Color(0x4DFFFFFF);
}

class HomeHeroRadius {
  static const double stageBottom = 30;
  static const double card = 24;
}

class HomeHeroShadows {
  static const List<BoxShadow> stageShadow = [
    BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 12)),
  ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, 8)),
  ];
}
```

If existing `AppColors`, `AppRadius`, or `AppShadows` already provide a matching value, reuse it instead of duplicating.

## Stage and App Bar Polish

- Apply a deep emerald gradient to the stage using `HomeHeroColors.stageTop` to `HomeHeroColors.stageBottom`.
- Keep the current title row, title alignment, bell position, top padding, and bottom curve behavior.
- Use a centered title with strong but not oversized typography:
  - Color: `HomeHeroColors.textPrimary`
  - Font size: current size or up to `28`
  - Font weight: `FontWeight.w700`
  - Letter spacing: `0`
- Keep the bell action behavior unchanged.
- Bell surface should remain circular with a translucent fill and subtle white border.
- Keep the unread badge position, size, and behavior unchanged.

## Main Card Polish

- Keep the existing card placement and two-column structure.
- Use a card gradient that is lighter than the stage:
  - `HomeHeroColors.cardTopLeft`
  - `HomeHeroColors.cardBottomRight`
- Use a subtle one-pixel translucent border:
  - `HomeHeroColors.cardBorder`
- Use one soft card shadow only:
  - `HomeHeroShadows.cardShadow`
- Do not add heavy blur, glow, image backgrounds, mosque patterns, or decorative texture.
- Optional: add one very subtle radial/top highlight only if it can be done with a `Stack` or `DecoratedBox` without moving any child element. The highlight must be low opacity and must not reduce text readability.

## Countdown Ring and Text Polish

- Keep the ring size, position, and countdown calculation unchanged.
- Keep the custom painter approach.
- Use:
  - Track: `HomeHeroColors.ringTrack`
  - Progress: `HomeHeroColors.ringProgress`
  - Stroke cap: round
- Do not add glow around the ring.
- Countdown number should be the strongest left-side text:
  - Color: `HomeHeroColors.textPrimary`
  - Font weight: `FontWeight.w700`
  - Use tabular figures as currently done
  - Avoid making the number so large that it feels cramped inside the ring
- Countdown label should be secondary:
  - Color: `HomeHeroColors.textSecondary`
  - Font weight: `FontWeight.w500`
  - Keep it single-line where possible without changing layout

## Right-Side Info Polish

Use a clear text hierarchy:

```text
Primary: location title, live clock, main Gregorian date
Secondary: icons, dropdown arrow, Hijri date
Muted: Bangla date, place-name metadata, low-priority loading/info text
```

Recommended styling:

- Location/dropdown text: primary white, medium-semibold weight.
- Divider/underline: `HomeHeroColors.divider`.
- Clock icon and location icon: `HomeHeroColors.textSecondary`.
- Live clock: primary white, bold enough to scan quickly.
- Gregorian date: primary white with medium weight.
- Hijri date: secondary white.
- Bangla date and place-name text: muted white.
- Keep long place names ellipsized.

## File Scope For Future Implementation

Allowed files:

- `lib/screens/home_screen.dart`
- `lib/widgets/prayer_countdown_widget.dart`
- `lib/core/app_theme_tokens.dart`

Do not edit other files unless a compile error proves a small import or token reference adjustment is required.

## QA Checklist

Verify on small and medium phone widths:

- Stage is darker than the main card.
- Main card is clear, clean, and visually separate from the stage.
- Card does not look flat, neon, gloomy, or overly glossy.
- Countdown ring remains in the same position and size.
- Countdown number remains readable inside the ring.
- Right-side text hierarchy is clear.
- Long location names still ellipsize.
- Bangla date and Hijri date do not overflow.
- Bell icon and unread badge still behave the same.
- Prayer, countdown, location, and notification behavior are unchanged.
- No new layout shift or overflow is introduced.

## Implementation Validation

After future implementation, run:

```powershell
$env:DART_SUPPRESS_ANALYTICS='true'; $env:APPDATA='C:\Users\SADAT\AppData\Local\Temp'; C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\core\app_theme_tokens.dart lib\screens\home_screen.dart lib\widgets\prayer_countdown_widget.dart
flutter analyze lib\core\app_theme_tokens.dart lib\screens\home_screen.dart lib\widgets\prayer_countdown_widget.dart
git diff --check -- lib\core\app_theme_tokens.dart lib\screens\home_screen.dart lib\widgets\prayer_countdown_widget.dart
```

## Final Deliverable For Future Implementation

Report:

1. Files changed.
2. Tokens added or updated.
3. Confirmation that the stage is darker than the main card.
4. Confirmation that no element layout changed.
5. Confirmation that prayer, countdown, location, and notification logic were not changed.
6. Any visual risks that remain, especially overflow on small screens.
