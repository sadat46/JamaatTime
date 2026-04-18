import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/locale_text.dart';

class CalendarSelectedDateCard extends StatelessWidget {
  const CalendarSelectedDateCard({
    super.key,
    required this.gregorianDate,
    required this.weekday,
    required this.banglaDate,
    required this.hijriDate,
    required this.cardBackground,
    required this.borderColor,
  });

  final String gregorianDate;
  final String weekday;
  final String banglaDate;
  final String hijriDate;
  final Color cardBackground;
  final Color borderColor;

  String _normalizedChipValue(String value) {
    return value
        .replaceAll(RegExp(r'\b(Bongabdo|Bangabdo)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bAH\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Widget _buildDateChip(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final displayValue = _normalizedChipValue(value);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppConstants.brandGreen.withValues(alpha: 0.16)
            : AppConstants.brandGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? AppConstants.brandGreen.withValues(alpha: 0.35)
              : AppConstants.brandGreen.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label:
          context.tr(
            bn: 'নির্বাচিত তারিখ $gregorianDate, $weekday। বাংলা ${_normalizedChipValue(banglaDate)}। হিজরি ${_normalizedChipValue(hijriDate)}।',
            en: 'Selected date $gregorianDate, $weekday. Bangla ${_normalizedChipValue(banglaDate)}. Hijri ${_normalizedChipValue(hijriDate)}.',
          ),
      child: Container(
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? AppConstants.brandGreen.withValues(alpha: 0.2)
                        : AppConstants.brandGreen.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event,
                    size: 18,
                    color: isDarkMode
                        ? Colors.white70
                        : AppConstants.brandGreenDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 24,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          maxLines: 1,
                          softWrap: false,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: gregorianDate,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDarkMode
                                      ? Colors.white
                                      : AppConstants.brandGreenDark,
                                ),
                              ),
                              TextSpan(
                                text: '  ',
                                style: TextStyle(
                                  fontSize: 17,
                                  color: isDarkMode
                                      ? Colors.white
                                      : AppConstants.brandGreenDark,
                                ),
                              ),
                              TextSpan(
                                text: weekday,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : AppConstants.brandGreenDark
                                            .withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 8.0;
                final chipWidth = constraints.maxWidth > (spacing * 2)
                    ? (constraints.maxWidth - (spacing * 2)) / 3
                    : constraints.maxWidth;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    SizedBox(
                      width: chipWidth,
                      child: Semantics(
                        label: context.tr(
                          bn: 'ইংরেজি তারিখ ${_normalizedChipValue(gregorianDate)}',
                          en: 'English date ${_normalizedChipValue(gregorianDate)}',
                        ),
                        child: _buildDateChip(
                          context,
                          label: context.tr(bn: 'ইংরেজি', en: 'English'),
                          value: gregorianDate,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: chipWidth,
                      child: Semantics(
                        label: context.tr(
                          bn: 'বাংলা তারিখ ${_normalizedChipValue(banglaDate)}',
                          en: 'Bangla date ${_normalizedChipValue(banglaDate)}',
                        ),
                        child: _buildDateChip(
                          context,
                          label: context.tr(bn: 'বাংলা', en: 'Bangla'),
                          value: banglaDate,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: chipWidth,
                      child: Semantics(
                        label: context.tr(
                          bn: 'হিজরি তারিখ ${_normalizedChipValue(hijriDate)}',
                          en: 'Hijri date ${_normalizedChipValue(hijriDate)}',
                        ),
                        child: _buildDateChip(
                          context,
                          label: context.tr(bn: 'হিজরি', en: 'Hijri'),
                          value: hijriDate,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
