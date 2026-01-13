import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/jamaat_time_utility.dart';

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
    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(3),
      },
      children: [
        // Header row
        TableRow(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF145A32)
                : const Color(0xFF43A047),
          ),
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Prayer Name',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Prayer Time',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (showJamaatTimes)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Jamaat Time',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        // Prayer rows
        ...[
          'Fajr',
          'Sunrise',
          'Dahwah-e-kubrah',
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
                ? BoxDecoration(color: Colors.green.shade100)
                : null,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(name),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: Text(
                    timeStr,
                    style: const TextStyle(fontSize: 13),
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
                              ? const TextStyle(color: Colors.grey)
                              : const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        if (jamaatStr != '-') ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.mosque, size: 12, color: Colors.green),
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