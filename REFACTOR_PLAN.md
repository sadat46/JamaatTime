# Professional Refactoring Plan: Green Default Strategy & Dark Mode Contrast Fixes

## Executive Summary

This plan implements a "Green Default" theme strategy and resolves visual contrast issues across all themes. The refactoring centralizes color constants, ensures theme consistency, and guarantees text readability in Dark Mode.

---

## Table of Contents

1. [Phase 1: Foundation - Color Constants & Theme Infrastructure](#phase-1-foundation)
2. [Phase 2: Theme Standardization](#phase-2-theme-standardization)
3. [Phase 3: Screen-Level Theme Compliance](#phase-3-screen-level-theme-compliance)
4. [Phase 4: Widget-Level Dark Mode Fixes](#phase-4-widget-level-dark-mode-fixes)
5. [Phase 5: Detail Screens Contrast Fixes](#phase-5-detail-screens-contrast-fixes)
6. [Validation Checklist](#validation-checklist)

---

## Phase 1: Foundation - Color Constants & Theme Infrastructure {#phase-1-foundation}

### 1.1 Add Brand Color Constants

**File:** `lib/core/constants.dart`

**Current State (lines 1-32):** No color constants defined.

**Action:** Add brand colors to `AppConstants` class.

**Implementation:**
```dart
import 'package:flutter/material.dart';

class AppConstants {
  // ══════════════════════════════════════════════════════════════════════════
  // BRAND COLORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Primary brand green - used for AppBar, buttons, accents
  static const Color brandGreen = Color(0xFF388E3C);

  /// Dark green variant - for dark mode highlights
  static const Color brandGreenDark = Color(0xFF145A32);

  /// Light green variant - for backgrounds
  static const Color brandGreenLight = Color(0xFFE8F5E9);

  /// Dua/Hadith accent purple
  static const Color brandPurple = Color(0xFF6A1B9A);

  /// Ayat/Quran accent blue
  static const Color brandBlue = Color(0xFF1565C0);

  // ... existing constants remain unchanged ...
}
```

**Note:** Add `import 'package:flutter/material.dart';` at the top of the file.

---

### 1.2 Change Default Theme to Green

**File:** `lib/services/settings_service.dart`

**Current State (line 48):**
```dart
return prefs.getInt(_themeIndexKey) ?? 0;
```

**Action:** Change default from `0` (Dark) to `2` (Green).

**Implementation (line 48):**
```dart
return prefs.getInt(_themeIndexKey) ?? 2;
```

**Rationale:** New users will see the branded Green theme by default.

---

## Phase 2: Theme Standardization {#phase-2-theme-standardization}

### 2.1 Add AppBarTheme to Green Theme

**File:** `lib/themes/green_theme.dart`

**Current State (lines 1-7):**
```dart
import 'package:flutter/material.dart';

final ThemeData greenTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light),
  scaffoldBackgroundColor: const Color(0xFFE8F5E9),
  useMaterial3: true,
);
```

**Issue:** Missing `appBarTheme` - causes inconsistent AppBar styling.

**Implementation:**
```dart
import 'package:flutter/material.dart';
import '../core/constants.dart';

final ThemeData greenTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppConstants.brandGreen,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: AppConstants.brandGreenLight,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppConstants.brandGreen,
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Colors.black87),
    bodyMedium: TextStyle(color: Colors.black87),
    titleMedium: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
  ),
  useMaterial3: true,
);
```

---

### 2.2 Verify Dark Theme (No Change Required)

**File:** `lib/themes/dark_theme.dart`

**Current State:** Already correct.
```dart
appBarTheme: const AppBarTheme(
  backgroundColor: Color(0xFF23272A),  // Dark grey - CORRECT
  foregroundColor: Colors.white,
  elevation: 0,
),
```

**Action:** No changes needed. Verified correct.

---

### 2.3 Verify White Theme (No Change Required)

**File:** `lib/themes/white_theme.dart`

**Current State:** Already correct.
```dart
appBarTheme: const AppBarTheme(
  backgroundColor: Colors.white,           // White - CORRECT
  foregroundColor: Color(0xFF388E3C),      // Brand green - CORRECT
  elevation: 0,
),
```

**Action:** No changes needed. Verified correct.

---

## Phase 3: Screen-Level Theme Compliance {#phase-3-screen-level-theme-compliance}

### 3.1 Fix Home Screen AppBar

**File:** `lib/screens/home_screen.dart`

**Current State (lines 600-608):**
```dart
appBar: AppBar(
  title: const Text('Jamaat Time'),
  centerTitle: true,
  backgroundColor: Theme.of(context).brightness == Brightness.dark
      ? null
      : const Color(0xFF388E3C),
  foregroundColor: Colors.white,
  elevation: 2,
),
```

**Issue:** Hardcoded green color bypasses theme system.

**Implementation:**
```dart
appBar: AppBar(
  title: const Text('Jamaat Time'),
  centerTitle: true,
  backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
  foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
  elevation: 2,
),
```

**Also update RefreshIndicator (line 619):**

**Current:**
```dart
color: const Color(0xFF388E3C),
```

**Change to:**
```dart
color: Theme.of(context).colorScheme.primary,
```

---

### 3.2 Ebadat Screen - NO CHANGES REQUIRED

**File:** `lib/screens/ebadat/ebadat_screen.dart`

**Current State (lines 32-37):**
```dart
appBar: AppBar(
  title: const Text('ইবাদত'),
  centerTitle: true,
  backgroundColor: colorScheme.primary,
  foregroundColor: colorScheme.onPrimary,
  elevation: 2,
),
```

**Status:** Already theme-aware. No changes needed.

---

### 3.3 Fix Admin Jamaat Panel

**File:** `lib/screens/admin_jamaat_panel.dart`

**Current State (lines 657-664):**
```dart
return Scaffold(
  backgroundColor: const Color(0xFFE8F5E9),  // Hardcoded
  appBar: AppBar(
    title: const Text('Admin Jamaat Panel'),
    centerTitle: true,
    backgroundColor: const Color(0xFF388E3C),  // Hardcoded
    foregroundColor: Colors.white,
    elevation: 2,
```

**Implementation:**
```dart
return Scaffold(
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  appBar: AppBar(
    title: const Text('Admin Jamaat Panel'),
    centerTitle: true,
    backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
    foregroundColor: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
    elevation: 2,
```

---

### 3.4 Fix User Management Screen (TWO Locations)

**File:** `lib/screens/user_management_screen.dart`

**Location 1 - Access Denied View (lines 457-464):**

**Current:**
```dart
return Scaffold(
  backgroundColor: const Color(0xFFE8F5E9),
  appBar: AppBar(
    title: const Text('User Management'),
    centerTitle: true,
    backgroundColor: const Color(0xFF388E3C),
    foregroundColor: Colors.white,
    elevation: 2,
  ),
```

**Change to:**
```dart
return Scaffold(
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  appBar: AppBar(
    title: const Text('User Management'),
    centerTitle: true,
    backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
    foregroundColor: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
    elevation: 2,
  ),
```

**Location 2 - Main View (lines 498-505):**

**Current:**
```dart
return Scaffold(
  backgroundColor: const Color(0xFFE8F5E9),
  appBar: AppBar(
    title: const Text('User Management'),
    centerTitle: true,
    backgroundColor: const Color(0xFF388E3C),
    foregroundColor: Colors.white,
    elevation: 2,
```

**Change to:**
```dart
return Scaffold(
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  appBar: AppBar(
    title: const Text('User Management'),
    centerTitle: true,
    backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
    foregroundColor: Theme.of(context).appBarTheme.foregroundColor ?? Colors.white,
    elevation: 2,
```

---

## Phase 4: Widget-Level Dark Mode Fixes {#phase-4-widget-level-dark-mode-fixes}

### 4.1 Fix Prayer Time Table Highlight

**File:** `lib/widgets/prayer_time_table.dart`

**Current State (lines 89-92):**
```dart
final isCurrent = name == currentPrayer;
return TableRow(
  decoration: isCurrent
      ? BoxDecoration(color: Colors.green.shade100)
      : null,
```

**Issue:** `Colors.green.shade100` is invisible/jarring in dark mode.

**Implementation:**
```dart
final isCurrent = name == currentPrayer;
final isDark = Theme.of(context).brightness == Brightness.dark;
return TableRow(
  decoration: isCurrent
      ? BoxDecoration(
          color: isDark
              ? const Color(0xFF388E3C).withOpacity(0.3)
              : Colors.green.shade100,
        )
      : null,
```

**Also fix header row (lines 33-37):**

**Current:**
```dart
decoration: BoxDecoration(
  color: Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF145A32)
      : const Color(0xFF43A047),
),
```

**Change to (use constants):**
```dart
decoration: BoxDecoration(
  color: Theme.of(context).brightness == Brightness.dark
      ? AppConstants.brandGreenDark
      : AppConstants.brandGreen,
),
```

**Add import at top:**
```dart
import '../core/constants.dart';
```

---

### 4.2 Fix Dua Card Dark Mode

**File:** `lib/widgets/ebadat/dua_card.dart`

**Arabic Text Container (lines 150-167):**

**Current:**
```dart
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.grey[50],
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    widget.dua.arabicText,
    textAlign: TextAlign.right,
    style: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      height: 1.8,
      color: Colors.black87,
    ),
  ),
),
```

**Implementation:**
```dart
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[800]
        : Colors.grey[50],
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    widget.dua.arabicText,
    textAlign: TextAlign.right,
    style: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      height: 1.8,
      color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
    ),
  ),
),
```

**Bangla Meaning Container (lines 186-202):**

**Current:**
```dart
Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
  decoration: BoxDecoration(
    color: const Color(0xFF6A1B9A).withValues(alpha: 0.05),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    widget.dua.banglaMeaning,
    style: const TextStyle(
      fontSize: 15,
      height: 1.6,
      color: Colors.black87,
    ),
  ),
),
```

**Implementation:**
```dart
Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
  decoration: BoxDecoration(
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF6A1B9A).withOpacity(0.15)
        : const Color(0xFF6A1B9A).withOpacity(0.05),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    widget.dua.banglaMeaning,
    style: TextStyle(
      fontSize: 15,
      height: 1.6,
      color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
    ),
  ),
),
```

**Also fix Transliteration text (lines 176-179):**
```dart
style: TextStyle(
  fontSize: 14,
  fontStyle: FontStyle.italic,
  color: Theme.of(context).brightness == Brightness.dark
      ? Colors.grey[400]
      : Colors.grey[700],
  height: 1.5,
),
```

---

### 4.3 Fix Ayat Card Dark Mode

**File:** `lib/widgets/ebadat/ayat_card.dart`

**Arabic Text Container (lines 178-195):**

**Current:**
```dart
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.grey[50],
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    widget.ayat.arabicText,
    textAlign: TextAlign.right,
    style: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      height: 1.8,
      color: Colors.black87,
    ),
  ),
),
```

**Implementation:**
```dart
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[800]
        : Colors.grey[50],
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    widget.ayat.arabicText,
    textAlign: TextAlign.right,
    style: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      height: 1.8,
      color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
    ),
  ),
),
```

**Bangla Meaning Container (lines 214-230):**

**Current:**
```dart
Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
  decoration: BoxDecoration(
    color: const Color(0xFF388E3C).withValues(alpha: 0.05),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    widget.ayat.banglaMeaning,
    style: const TextStyle(
      fontSize: 15,
      height: 1.6,
      color: Colors.black87,
    ),
  ),
),
```

**Implementation:**
```dart
Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
  decoration: BoxDecoration(
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF388E3C).withOpacity(0.15)
        : const Color(0xFF388E3C).withOpacity(0.05),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(
    widget.ayat.banglaMeaning,
    style: TextStyle(
      fontSize: 15,
      height: 1.6,
      color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
    ),
  ),
),
```

**Also fix Transliteration text (lines 204-207):**
```dart
style: TextStyle(
  fontSize: 14,
  fontStyle: FontStyle.italic,
  color: Theme.of(context).brightness == Brightness.dark
      ? Colors.grey[400]
      : Colors.grey[700],
  height: 1.5,
),
```

---

## Phase 5: Detail Screens Contrast Fixes {#phase-5-detail-screens-contrast-fixes}

### 5.1 Fix Dua Detail Screen

**File:** `lib/screens/ebadat/dua_detail_screen.dart`

**AppBar (lines 127-136):**

**Current:**
```dart
appBar: AppBar(
  title: Text(
    widget.dua.titleBangla,
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
  ),
  backgroundColor: const Color(0xFF6A1B9A),
  iconTheme: const IconThemeData(color: Colors.white),
```

**Implementation:**
```dart
appBar: AppBar(
  title: Text(
    widget.dua.titleBangla,
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
  ),
  backgroundColor: Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF4A148C)  // Darker purple for dark mode
      : const Color(0xFF6A1B9A),
  iconTheme: const IconThemeData(color: Colors.white),
```

**Category Badge (lines 168-188):**

**Current:**
```dart
decoration: BoxDecoration(
  color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
  borderRadius: BorderRadius.circular(20),
  border: Border.all(
    color: const Color(0xFF6A1B9A).withValues(alpha: 0.3),
  ),
),
child: Text(
  widget.dua.category,
  style: const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xFF6A1B9A),
  ),
),
```

**Implementation:**
```dart
decoration: BoxDecoration(
  color: Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF6A1B9A).withOpacity(0.2)
      : const Color(0xFF6A1B9A).withOpacity(0.1),
  borderRadius: BorderRadius.circular(20),
  border: Border.all(
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9C4DCC).withOpacity(0.5)
        : const Color(0xFF6A1B9A).withOpacity(0.3),
  ),
),
child: Text(
  widget.dua.category,
  style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFCE93D8)  // Light purple for dark mode
        : const Color(0xFF6A1B9A),
  ),
),
```

**Arabic Text Container (lines 193-214):**

**Current:**
```dart
Container(
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
    color: Colors.grey[50],
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: const Color(0xFF4A148C).withValues(alpha: 0.2),
      width: 2,
    ),
  ),
  child: Text(
    widget.dua.arabicText,
    textAlign: TextAlign.center,
    textDirection: TextDirection.rtl,
    style: const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w500,
      height: 2.0,
      color: Color(0xFF4A148C),
    ),
  ),
),
```

**Implementation:**
```dart
Container(
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[850]
        : Colors.grey[50],
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF9C4DCC).withOpacity(0.3)
          : const Color(0xFF4A148C).withOpacity(0.2),
      width: 2,
    ),
  ),
  child: Text(
    widget.dua.arabicText,
    textAlign: TextAlign.center,
    textDirection: TextDirection.rtl,
    style: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w500,
      height: 2.0,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFCE93D8)  // Light purple for dark mode
          : const Color(0xFF4A148C),
    ),
  ),
),
```

**Note:** Apply similar dark mode fixes to all other hardcoded purple colors (`0xFF6A1B9A`, `0xFF4A148C`) throughout the file, including icons and section headers.

---

### 5.2 Fix Ayat Detail Screen

**File:** `lib/screens/ebadat/ayat_detail_screen.dart`

**AppBar (lines 127-136):**

**Current:**
```dart
appBar: AppBar(
  title: Text(
    widget.ayat.titleBangla,
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
  ),
  backgroundColor: const Color(0xFF388E3C),
  iconTheme: const IconThemeData(color: Colors.white),
```

**Implementation:**
```dart
appBar: AppBar(
  title: Text(
    widget.ayat.titleBangla,
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
  ),
  backgroundColor: Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF1B5E20)  // Darker green for dark mode
      : const Color(0xFF388E3C),
  iconTheme: const IconThemeData(color: Colors.white),
```

**Category Badge (lines 168-188):**

**Current:**
```dart
decoration: BoxDecoration(
  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
  ...
),
child: Text(
  widget.ayat.category,
  style: const TextStyle(
    ...
    color: Color(0xFF1565C0),
  ),
),
```

**Implementation:**
```dart
decoration: BoxDecoration(
  color: Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF1565C0).withOpacity(0.2)
      : const Color(0xFF1565C0).withOpacity(0.1),
  borderRadius: BorderRadius.circular(20),
  border: Border.all(
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF64B5F6).withOpacity(0.5)
        : const Color(0xFF1565C0).withOpacity(0.3),
  ),
),
child: Text(
  widget.ayat.category,
  style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF90CAF9)  // Light blue for dark mode
        : const Color(0xFF1565C0),
  ),
),
```

**Arabic Text Container (lines 193-214):**

**Current:**
```dart
Container(
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
    color: Colors.grey[50],
    ...
  ),
  child: Text(
    widget.ayat.arabicText,
    ...
    style: const TextStyle(
      ...
      color: Color(0xFF1B5E20),
    ),
  ),
),
```

**Implementation:**
```dart
Container(
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
    color: Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[850]
        : Colors.grey[50],
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF81C784).withOpacity(0.3)
          : const Color(0xFF1B5E20).withOpacity(0.2),
      width: 2,
    ),
  ),
  child: Text(
    widget.ayat.arabicText,
    textAlign: TextAlign.center,
    textDirection: TextDirection.rtl,
    style: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w500,
      height: 2.0,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF81C784)  // Light green for dark mode
          : const Color(0xFF1B5E20),
    ),
  ),
),
```

**Note:** Apply similar dark mode fixes to all other hardcoded colors (`0xFF1565C0`, `0xFF1B5E20`) throughout the file, including icons and section headers.

---

## Validation Checklist {#validation-checklist}

### Pre-Implementation Verification
- [ ] Confirm theme index mapping: 0=Dark, 1=White, 2=Green
- [ ] Backup current working state

### Post-Implementation Testing

#### Theme Switching Tests
- [ ] Fresh install shows Green theme by default
- [ ] Settings > Theme switching works for all 3 themes
- [ ] Theme persists after app restart

#### Green Theme Validation
- [ ] Home Screen: Green AppBar with white text
- [ ] Ebadat Screen: Green AppBar (matches Home)
- [ ] Admin Panel: Green AppBar, light green scaffold
- [ ] User Management: Green AppBar, light green scaffold

#### Dark Theme Validation
- [ ] Home Screen: Dark grey AppBar (0xFF23272A)
- [ ] All text is readable (white/light colors)
- [ ] Prayer table highlight visible (green with 30% opacity)
- [ ] Dua cards: Arabic text readable (light text on dark bg)
- [ ] Ayat cards: Arabic text readable (light text on dark bg)
- [ ] Detail screens: All text has sufficient contrast

#### White Theme Validation
- [ ] Home Screen: White AppBar with green text
- [ ] All screens consistent
- [ ] No invisible text

#### Component-Specific Tests
- [ ] Prayer Time Table: Current prayer row visible in all themes
- [ ] Dua Card: Arabic, transliteration, meaning all readable
- [ ] Ayat Card: Arabic, transliteration, meaning all readable
- [ ] Dua Detail: All sections readable in dark mode
- [ ] Ayat Detail: All sections readable in dark mode

### Build Verification
- [ ] `flutter analyze` passes with no errors
- [ ] `flutter build apk --release` succeeds
- [ ] No runtime theme-related exceptions

---

## Files Modified Summary

| File | Changes |
|------|---------|
| `lib/core/constants.dart` | Add 5 brand color constants |
| `lib/services/settings_service.dart` | Change default theme to `2` |
| `lib/themes/green_theme.dart` | Add complete `appBarTheme` |
| `lib/themes/dark_theme.dart` | No changes (verified correct) |
| `lib/themes/white_theme.dart` | No changes (verified correct) |
| `lib/screens/home_screen.dart` | Use theme AppBar colors |
| `lib/screens/ebadat/ebadat_screen.dart` | No changes (already theme-aware) |
| `lib/screens/admin_jamaat_panel.dart` | Use theme scaffold/AppBar colors |
| `lib/screens/user_management_screen.dart` | Fix 2 locations |
| `lib/widgets/prayer_time_table.dart` | Dark mode highlight fix |
| `lib/widgets/ebadat/dua_card.dart` | Dark mode text/bg fixes |
| `lib/widgets/ebadat/ayat_card.dart` | Dark mode text/bg fixes |
| `lib/screens/ebadat/dua_detail_screen.dart` | Comprehensive dark mode fixes |
| `lib/screens/ebadat/ayat_detail_screen.dart` | Comprehensive dark mode fixes |

**Total Files: 14 | Modified: 12 | Unchanged: 2**

---

## Implementation Order (Dependency-Aware)

1. **Phase 1.1** - `constants.dart` (foundation - other files depend on this)
2. **Phase 2.1** - `green_theme.dart` (depends on constants)
3. **Phase 1.2** - `settings_service.dart` (independent)
4. **Phase 3.1-3.4** - Screen files (depend on themes)
5. **Phase 4.1-4.3** - Widget files (depend on themes)
6. **Phase 5.1-5.2** - Detail screens (depend on themes)
7. **Validation** - Run all tests

---

*Plan Version: 1.0*
*Generated: 2026-01-15*
*Target: Claude Sonnet 4.5 Implementation*
