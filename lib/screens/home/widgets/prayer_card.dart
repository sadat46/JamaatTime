import 'package:flutter/material.dart';

import '../../../core/app_theme_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/locale_digits.dart';
import '../models/prayer_row_data.dart';

class PrayerCard extends StatelessWidget {
  const PrayerCard({super.key, required this.row});

  final PrayerRowData row;

  @override
  Widget build(BuildContext context) {
    final isInfo = row.type == PrayerRowType.info;
    final isActive = row.isCurrent;
    final localizedTimeStr = _localizedDigitsForContext(context, row.timeStr);
    final localizedJamaatStr = _localizedDigitsForContext(
      context,
      row.jamaatStr,
    );
    final hasJamaat = row.jamaatStr != '-';
    final prayerIcon = _prayerIconForName(row.name);
    final iconAccent = _prayerIconAccent(row.name);
    final iconTint = _prayerIconTint(row.name);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.row),
          color: isActive
              ? AppColors.activeFill
              : isInfo
              ? AppColors.primarySoft2
              : AppColors.cardBackground,
          border: Border.all(
            color: isActive ? AppColors.borderActive : AppColors.borderLight,
          ),
          boxShadow: AppShadows.subtle,
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              if (isActive)
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: AppColors.activeAccent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(AppRadius.row),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isActive ? 12.0 : 16.0,
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
                              alpha: isActive ? 0.42 : 0.24,
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
                          style: TextStyle(
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontStyle: isInfo
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: isActive
                                ? AppColors.primaryDark
                                : isInfo
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            fontSize: 15,
                            height: 1.15,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          localizedTimeStr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontStyle: isInfo
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: isActive
                                ? AppColors.primaryDark
                                : AppColors.textPrimary,
                            height: 1.15,
                          ),
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
                                style: !hasJamaat
                                    ? const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 14,
                                      )
                                    : TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryGreen,
                                        fontSize: 14,
                                      ),
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
