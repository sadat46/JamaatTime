import 'package:flutter/material.dart';

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
  static const warningBorder = Color(0xFFF0DDD0);

  static const navInactive = Color(0xFF6B746D);

  static const fajrBadge = Color(0xFFEAF4FF);
  static const sunriseBadge = Color(0xFFFFF4DA);
  static const dhuhrBadge = Color(0xFFFFF0E0);
  static const asrBadge = Color(0xFFE7F6F2);
  static const maghribBadge = Color(0xFFF8EFE6);
  static const ishaBadge = Color(0xFFEFEFFF);
}

class AppRadius {
  static const double card = 22;
  static const double row = 16;
  static const double chip = 999;
}

class AppShadows {
  static const List<BoxShadow> softCard = [
    BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 7)),
  ];

  static const List<BoxShadow> subtle = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> navBar = [
    BoxShadow(color: Color(0x10000000), blurRadius: 12, offset: Offset(0, -4)),
  ];
}
