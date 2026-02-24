# Theme Testing Checklist - Jamaat Time App

## Testing Overview
This checklist validates the "Green Default" strategy and Dark Mode contrast fixes implemented across all three themes.

---

## Pre-Test Setup

### Fresh Install Test
- [ ] Uninstall the app completely from your device
- [ ] Reinstall the app
- [ ] **Expected**: App launches with **Green Theme** by default

### Access Theme Settings
- [ ] Navigate to: **Profile/Settings → Theme Selection**
- [ ] Verify all three options are available: Dark, White, Green

---

## Theme 1: Green Theme (Default) 🟢

### Home Screen
- [ ] AppBar background is **Green** (#388E3C)
- [ ] AppBar text is **White**
- [ ] Scaffold background is **Light Green** (#E8F5E9)
- [ ] Prayer time table header is **Green**
- [ ] Current prayer row highlight is visible (light green background)
- [ ] Refresh indicator is **Green**

### Ebadat Screen
- [ ] AppBar background is **Green** (matches Home Screen)
- [ ] AppBar text is **White**
- [ ] Dua Cards:
  - [ ] Arabic text is readable (black on light grey background)
  - [ ] Transliteration is readable (grey text)
  - [ ] Bangla meaning has light purple background with black text

- [ ] Ayat Cards:
  - [ ] Arabic text is readable (black on light grey background)
  - [ ] Transliteration is readable (grey text)
  - [ ] Bangla meaning has light green background with black text

### Dua Detail Screen
- [ ] AppBar is **Purple** (#6A1B9A) with white text
- [ ] Category badge has purple accent
- [ ] Arabic text container has grey background with dark purple text
- [ ] Transliteration section readable
- [ ] Meaning section has purple background with black text
- [ ] Share button is purple

### Ayat Detail Screen
- [ ] AppBar is **Green** (#388E3C) with white text
- [ ] Category badge has blue accent
- [ ] Arabic text container has grey background with dark green text
- [ ] Transliteration section readable
- [ ] Meaning section has blue background with black text
- [ ] Share button is blue

### Admin Screens (if accessible)
- [ ] Admin Jamaat Panel:
  - [ ] AppBar is **Green**
  - [ ] Scaffold background is **Light Green**

- [ ] User Management:
  - [ ] AppBar is **Green**
  - [ ] Scaffold background is **Light Green**
  - [ ] Access denied screen (if not admin) matches theme

---

## Theme 2: Dark Theme 🌙

### Home Screen
- [ ] AppBar background is **Dark Grey** (#23272A)
- [ ] AppBar text is **White**
- [ ] Scaffold background is **Very Dark** (#181A1B)
- [ ] Prayer time table header is **Dark Green** (#145A32)
- [ ] Current prayer row highlight is visible (green with 30% opacity)
- [ ] All text is **readable** (white/light colors)

### Ebadat Screen
- [ ] AppBar matches theme (Dark Grey)
- [ ] Dua Cards:
  - [ ] Arabic text is **readable** (light text on dark grey background)
  - [ ] Transliteration is **readable** (light grey text)
  - [ ] Bangla meaning has darker purple background with **light text**

- [ ] Ayat Cards:
  - [ ] Arabic text is **readable** (light text on dark grey background)
  - [ ] Transliteration is **readable** (light grey text)
  - [ ] Bangla meaning has darker green background with **light text**

### Dua Detail Screen
- [ ] AppBar is **Dark Purple** (#4A148C) - darker than light mode
- [ ] Category badge has **light purple** text (#CE93D8) - readable!
- [ ] Arabic text container:
  - [ ] Background is very dark grey (#850)
  - [ ] Text is **light purple** (#CE93D8) - readable!
- [ ] Reference icon and text are **light purple**
- [ ] Transliteration has darker purple background with **light grey text**
- [ ] Meaning section has darker purple background with **white text**
- [ ] Section headers are **light purple** - readable!
- [ ] Share button is dark purple

### Ayat Detail Screen
- [ ] AppBar is **Dark Green** (#1B5E20) - darker than light mode
- [ ] Category badge has **light blue** text (#90CAF9) - readable!
- [ ] Arabic text container:
  - [ ] Background is very dark grey (#850)
  - [ ] Text is **light green** (#81C784) - readable!
- [ ] Surah info icon and text are **light blue**
- [ ] Transliteration has darker blue background with **light grey text**
- [ ] Meaning section has darker blue background with **white text**
- [ ] Section headers are **light blue** - readable!
- [ ] Action buttons have appropriate contrast

### Admin Screens (if accessible)
- [ ] Admin Jamaat Panel:
  - [ ] AppBar matches dark theme
  - [ ] Scaffold background is dark
  - [ ] All text is readable

- [ ] User Management:
  - [ ] AppBar matches dark theme
  - [ ] All text is readable

---

## Theme 3: White Theme ⚪

### Home Screen
- [ ] AppBar background is **White**
- [ ] AppBar text is **Green** (#388E3C)
- [ ] Scaffold background is **White**
- [ ] Prayer time table header is **Green**
- [ ] Current prayer row highlight is visible (light green background)
- [ ] All text is **readable** (black/dark colors)

### Ebadat Screen
- [ ] AppBar background is **White** with green text
- [ ] Dua Cards:
  - [ ] Arabic text is readable (black on light grey background)
  - [ ] Transliteration is readable (grey text)
  - [ ] Bangla meaning has light purple background with black text

- [ ] Ayat Cards:
  - [ ] Arabic text is readable (black on light grey background)
  - [ ] Transliteration is readable (grey text)
  - [ ] Bangla meaning has light green background with black text

### Dua Detail Screen
- [ ] AppBar is **Purple** (#6A1B9A) with white text
- [ ] Category badge has purple accent with good contrast
- [ ] Arabic text readable
- [ ] All sections readable
- [ ] Share button is purple

### Ayat Detail Screen
- [ ] AppBar is **Green** (#388E3C) with white text
- [ ] Category badge has blue accent with good contrast
- [ ] Arabic text readable
- [ ] All sections readable
- [ ] Share button is blue

### Admin Screens (if accessible)
- [ ] Admin Jamaat Panel:
  - [ ] AppBar matches white theme
  - [ ] Scaffold background is white

- [ ] User Management:
  - [ ] AppBar matches white theme
  - [ ] All text is readable

---

## Cross-Theme Tests

### Theme Switching
- [ ] Switch from Green → Dark
  - [ ] Theme changes immediately
  - [ ] No crashes or visual glitches
  - [ ] All text remains readable

- [ ] Switch from Dark → White
  - [ ] Theme changes immediately
  - [ ] No crashes or visual glitches
  - [ ] All text remains readable

- [ ] Switch from White → Green
  - [ ] Theme changes immediately
  - [ ] No crashes or visual glitches
  - [ ] All text remains readable

### Theme Persistence
- [ ] Set theme to **Dark**
- [ ] Close the app completely
- [ ] Reopen the app
- [ ] **Expected**: App opens with **Dark** theme (persisted)

- [ ] Set theme to **White**
- [ ] Close the app completely
- [ ] Reopen the app
- [ ] **Expected**: App opens with **White** theme (persisted)

### Navigation Consistency
For each theme, verify:
- [ ] Home Screen → Ebadat Screen → Dua Detail
  - [ ] All AppBars consistent within their color scheme
  - [ ] No jarring color changes
  - [ ] Back navigation works correctly

- [ ] Home Screen → Profile/Settings
  - [ ] Theme selection shows current theme
  - [ ] All settings screens follow theme

---

## Critical Visual Tests

### Dark Mode Readability (Most Important!)
In **Dark Theme**, verify NO invisible text:
- [ ] Home Screen: All prayer times readable
- [ ] Ebadat Cards: Arabic, transliteration, meaning all visible
- [ ] Dua Detail: Every section readable (especially purple text)
- [ ] Ayat Detail: Every section readable (especially blue/green text)
- [ ] Settings: All options readable

### Color Consistency
- [ ] Green Theme: Green AppBars everywhere (except detail screens)
- [ ] Dark Theme: Dark Grey AppBars everywhere (except detail screens)
- [ ] White Theme: White AppBars with green text everywhere (except detail screens)

### Special Cases
- [ ] Dua Detail screens have **purple** theme accent (in all 3 themes)
- [ ] Ayat Detail screens have **green/blue** theme accent (in all 3 themes)
- [ ] Admin screens follow base theme, not detail screen colors

---

## Performance Tests

### Theme Switching Performance
- [ ] No lag when switching themes
- [ ] No frame drops
- [ ] Smooth transitions

### Memory Leaks
- [ ] Switch between all themes 10 times rapidly
- [ ] App remains responsive
- [ ] No crashes or freezing

---

## Edge Cases

### Fresh Install Default
- [ ] Uninstall app
- [ ] Reinstall app
- [ ] **Critical**: Verify Green Theme is the default (not Dark)

### First Launch
- [ ] Clear app data
- [ ] Launch app
- [ ] Verify Green Theme is default

### After Update
- [ ] If user had Dark theme before update
- [ ] After update, theme should remain Dark (not reset to Green)
- [ ] Theme preference is preserved

---

## Known Issues to Watch For

### Issues That Should NOT Occur (If Found, Report Bug):
- [ ] ❌ Invisible text in Dark Mode
- [ ] ❌ Hardcoded green color in White Theme AppBar
- [ ] ❌ Light grey text on light grey background
- [ ] ❌ Black text on dark background
- [ ] ❌ Theme not persisting after app restart
- [ ] ❌ Default theme is Dark instead of Green on fresh install

---

## Test Results Summary

| Theme | Status | Notes |
|-------|--------|-------|
| Green (Default) | ⬜ Pass / ⬜ Fail | |
| Dark | ⬜ Pass / ⬜ Fail | |
| White | ⬜ Pass / ⬜ Fail | |

### Critical Issues Found:
- [ ] None (all tests passed) ✅
- [ ] Issue 1: _______________
- [ ] Issue 2: _______________
- [ ] Issue 3: _______________

---

## Approvals

- [ ] **Developer Test**: All themes display correctly
- [ ] **UX Test**: Dark mode is readable and comfortable
- [ ] **Brand Test**: Green theme reflects brand identity
- [ ] **Ready for Release**: All critical tests passed

---

*Testing Date: ________________*
*Tester Name: ________________*
*App Version: ________________*
