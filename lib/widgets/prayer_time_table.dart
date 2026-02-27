import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/jamaat_time_utility.dart';
import '../core/constants.dart';

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
                'Prayer Name',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Prayer Time',
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
                  'Jamaat Time',
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
              ? DateFormat('HH:mm').format(t.toLocal())
              : '-';

          String jamaatStr = '-';
          if (showJamaatTimes) {
            jamaatStr = JamaatTimeUtility.instance.getJamaatTimeString(
              jamaatTimes: jamaatTimes,
              prayerName: name,
              maghribPrayerTime: times['Maghrib'],
              selectedCity: selectedCity,
            );
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
                  name,
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