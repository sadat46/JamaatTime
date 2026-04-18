import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/prayer_aux_calculator.dart';
import '../core/constants.dart';
import '../l10n/app_localizations.dart';
import '../utils/locale_digits.dart';

class PrayerTimeTable extends StatelessWidget {
  final Map<String, DateTime?> times;
  final Map<String, dynamic>? jamaatTimes;
  final String? selectedCity;
  final String currentPrayer;
  final bool showJamaatTimes;

  const PrayerTimeTable({
    super.key,
    required this.times,
    this.jamaatTimes,
    this.selectedCity,
    required this.currentPrayer,
    this.showJamaatTimes = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final strings = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final isEnglish = locale.languageCode == 'en';

    String localizedPrayerName(String name) {
      switch (name) {
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
          return name;
      }
    }

    return Table(
      border: TableBorder.all(
        color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
      ),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(3),
      },
      children: [
        // Header row
        TableRow(
          decoration: BoxDecoration(
            color: isDarkMode
                ? AppConstants.brandGreenDark
                : AppConstants.brandGreen,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                isEnglish ? 'Prayer Name' : 'নামাজের নাম',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                isEnglish ? 'Prayer Time' : 'নামাজের সময়',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.white,
                ),
              ),
            ),
            if (showJamaatTimes)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  isEnglish ? 'Jamaat Time' : 'জামাতের সময়',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.white,
                  ),
                ),
              ),
          ],
        ),
        // Prayer rows
        ...[
          'Fajr',
          'Sunrise',
          'Dhuhr',
          'Asr',
          'Maghrib',
          'Isha',
        ].map((name) {
          final t = times[name];
          final timeStr = t != null
              ? LocaleDigits.localize(DateFormat('HH:mm').format(t.toLocal()), locale)
              : '-';

          String jamaatStr = '-';
          if (showJamaatTimes) {
            jamaatStr = PrayerAuxCalculator.instance.getJamaatTimeString(
              jamaatTimes: jamaatTimes,
              prayerName: name,
              maghribPrayerTime: times['Maghrib'],
              selectedCity: selectedCity,
            );
            jamaatStr = LocaleDigits.localize(jamaatStr, locale);
          }

          final isCurrent = name == currentPrayer;
          return TableRow(
            decoration: isCurrent
                ? BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF2E7D32).withValues(alpha: 0.5)
                        : Colors.green.shade100,
                  )
                : null,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  localizedPrayerName(name),
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ),
              if (showJamaatTimes)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          jamaatStr,
                          style: jamaatStr == '-'
                              ? TextStyle(
                                  color: isDarkMode ? Colors.grey.shade600 : Colors.grey,
                                )
                              : TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? const Color(0xFF81C784)
                                      : Colors.green.shade700,
                                ),
                        ),
                        if (jamaatStr != '-') ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.mosque,
                            size: 12,
                            color: isDarkMode
                                ? const Color(0xFF81C784)
                                : Colors.green.shade700,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
} 
