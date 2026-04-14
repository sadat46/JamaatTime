import 'package:flutter/material.dart';

import '../core/constants.dart';

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

  ({String dayAndMonth, String year}) _splitDateValue(String value) {
    final parts = value.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final tokens = parts.toList();

    if (tokens.length < 3) {
      return (dayAndMonth: value, year: '');
    }

    return (
      dayAndMonth: '${tokens[0]} ${tokens[1]}',
      year: tokens.sublist(2).join(' '),
    );
  }

  Widget _buildDateChip(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final valueParts = _splitDateValue(value);

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
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white70 : AppConstants.brandGreenDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valueParts.dayAndMonth,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          if (valueParts.year.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              valueParts.year,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label:
          'Selected date $gregorianDate, $weekday. Bangla $banglaDate. Hijri $hijriDate.',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gregorianDate,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDarkMode
                              ? Colors.white
                              : AppConstants.brandGreenDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        weekday,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 8.0;
                final chipWidth = constraints.maxWidth > spacing
                    ? (constraints.maxWidth - spacing) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    SizedBox(
                      width: chipWidth,
                      child: Semantics(
                        label: 'Bangla date $banglaDate',
                        child: _buildDateChip(
                          context,
                          label: 'Bangla',
                          value: banglaDate,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: chipWidth,
                      child: Semantics(
                        label: 'Hijri date $hijriDate',
                        child: _buildDateChip(
                          context,
                          label: 'Hijri',
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
