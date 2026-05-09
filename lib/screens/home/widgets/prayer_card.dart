import 'package:flutter/material.dart';

import '../../../core/app_theme_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/locale_digits.dart';
import '../models/prayer_row_data.dart';

class _PrayerCardVisualSpec {
  const _PrayerCardVisualSpec({
    required this.cardColor,
    required this.borderColor,
    required this.horizontalPadding,
    required this.iconBorderAlpha,
    required this.nameTextStyle,
    required this.timeTextStyle,
  });

  factory _PrayerCardVisualSpec.from({required bool isInfo}) {
    if (isInfo) return info;
    return normal;
  }

  static const _PrayerCardVisualSpec info = _PrayerCardVisualSpec(
    cardColor: AppColors.primarySoft2,
    borderColor: AppColors.borderLight,
    horizontalPadding: 16.0,
    iconBorderAlpha: 0.24,
    nameTextStyle: TextStyle(
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.italic,
      color: AppColors.textSecondary,
      fontSize: 15,
      height: 1.15,
    ),
    timeTextStyle: TextStyle(
      fontSize: 14,
      fontStyle: FontStyle.italic,
      color: AppColors.textPrimary,
      height: 1.15,
    ),
  );

  static const _PrayerCardVisualSpec normal = _PrayerCardVisualSpec(
    cardColor: AppColors.cardBackground,
    borderColor: AppColors.borderLight,
    horizontalPadding: 16.0,
    iconBorderAlpha: 0.24,
    nameTextStyle: TextStyle(
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
      fontSize: 15,
      height: 1.15,
    ),
    timeTextStyle: TextStyle(
      fontSize: 14,
      color: AppColors.textPrimary,
      height: 1.15,
    ),
  );

  static const TextStyle jamaatTextStyle = TextStyle(
    fontWeight: FontWeight.w700,
    color: AppColors.primaryGreen,
    fontSize: 14,
  );

  static const TextStyle missingJamaatTextStyle = TextStyle(
    color: AppColors.textMuted,
    fontSize: 14,
  );

  final Color cardColor;
  final Color borderColor;
  final double horizontalPadding;
  final double iconBorderAlpha;
  final TextStyle nameTextStyle;
  final TextStyle timeTextStyle;
}

class PrayerCard extends StatelessWidget {
  const PrayerCard({super.key, required this.row});

  final PrayerRowData row;

  @override
  Widget build(BuildContext context) {
    final isInfo = row.type == PrayerRowType.info;
    final localizedTimeStr = _localizedDigitsForContext(context, row.timeStr);
    final localizedJamaatStr = _localizedDigitsForContext(
      context,
      row.jamaatStr,
    );
    final hasJamaat = row.jamaatStr != '-';
    final visualSpec = _PrayerCardVisualSpec.from(isInfo: isInfo);
    final prayerIcon = _prayerIconForName(row.name);
    final iconAccent = _prayerIconAccent(row.name);
    final iconTint = _prayerIconTint(row.name);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.row),
          color: visualSpec.cardColor,
          border: Border.all(color: visualSpec.borderColor),
          boxShadow: AppShadows.subtle,
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: visualSpec.horizontalPadding,
                    vertical: 12.0,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: iconTint,
                          border: Border.all(
                            color: iconAccent.withValues(
                              alpha: visualSpec.iconBorderAlpha,
                            ),
                          ),
                        ),
                        child: Icon(prayerIcon, size: 16, color: iconAccent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: Text(
                          _localizedPrayerName(context, row.name),
                          style: visualSpec.nameTextStyle,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          localizedTimeStr,
                          textAlign: TextAlign.center,
                          style: visualSpec.timeTextStyle,
                        ),
                      ),
                      if (!isInfo)
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                localizedJamaatStr,
                                style: hasJamaat
                                    ? _PrayerCardVisualSpec.jamaatTextStyle
                                    : _PrayerCardVisualSpec
                                          .missingJamaatTextStyle,
                              ),
                              if (hasJamaat) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.mosque,
                                  size: 12,
                                  color: AppColors.primaryGreen,
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _localizedDigitsForContext(BuildContext context, String value) {
    if (value == '-') return value;
    return LocaleDigits.localize(value, Localizations.localeOf(context));
  }

  String _localizedPrayerName(BuildContext context, String prayerName) {
    final strings = AppLocalizations.of(context);
    switch (prayerName) {
      case 'Fajr':
        return strings.prayer_fajr;
      case 'Sunrise':
        return strings.prayer_sunrise;
      case 'Dhuhr':
        return strings.prayer_dhuhr;
      case 'Asr':
        return strings.prayer_asr;
      case 'Maghrib':
        return strings.prayer_maghrib;
      case 'Isha':
        return strings.prayer_isha;
      default:
        return prayerName;
    }
  }

  IconData _prayerIconForName(String prayerName) {
    switch (prayerName) {
      case 'Fajr':
        return Icons.wb_twilight_outlined;
      case 'Sunrise':
        return Icons.wb_sunny_outlined;
      case 'Dhuhr':
        return Icons.wb_sunny;
      case 'Asr':
        return Icons.wb_cloudy_outlined;
      case 'Maghrib':
        return Icons.nights_stay_outlined;
      case 'Isha':
        return Icons.dark_mode_outlined;
      default:
        return Icons.schedule_outlined;
    }
  }

  Color _prayerIconAccent(String prayerName) {
    switch (prayerName) {
      case 'Fajr':
        return const Color(0xFF2A77D4);
      case 'Sunrise':
        return const Color(0xFFF2A93B);
      case 'Dhuhr':
        return const Color(0xFFDD8A2F);
      case 'Asr':
        return const Color(0xFF2B9B88);
      case 'Maghrib':
        return const Color(0xFFB7632A);
      case 'Isha':
        return const Color(0xFF5564C7);
      default:
        return AppColors.primaryGreen;
    }
  }

  Color _prayerIconTint(String prayerName) {
    switch (prayerName) {
      case 'Fajr':
        return AppColors.fajrBadge;
      case 'Sunrise':
        return AppColors.sunriseBadge;
      case 'Dhuhr':
        return AppColors.dhuhrBadge;
      case 'Asr':
        return AppColors.asrBadge;
      case 'Maghrib':
        return AppColors.maghribBadge;
      case 'Isha':
        return AppColors.ishaBadge;
      default:
        return AppColors.primarySoft;
    }
  }
}
