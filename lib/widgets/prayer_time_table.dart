import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class PrayerTimeTable extends StatelessWidget {
  final Map<String, DateTime?> prayerTimes;
  final Map<String, dynamic>? jamaatTimes;
  final String currentPrayerName;

  const PrayerTimeTable({
    super.key,
    required this.prayerTimes,
    this.jamaatTimes,
    required this.currentPrayerName,
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
          children: const [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Prayer Name',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Prayer Time',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
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
          final t = prayerTimes[name];
          final timeStr = t != null
              ? DateFormat('HH:mm').format(
                  tz.TZDateTime.from(
                    t,
                    tz.getLocation('Asia/Dhaka'),
                  ),
                )
              : '-';

          // Map prayer names to jamaat time keys
          String jamaatKey;
          switch (name) {
            case 'Fajr':
              jamaatKey = 'fajr';
              break;
            case 'Dhuhr':
              jamaatKey = 'dhuhr';
              break;
            case 'Asr':
              jamaatKey = 'asr';
              break;
            case 'Maghrib':
              jamaatKey = 'maghrib';
              break;
            case 'Isha':
              jamaatKey = 'isha';
              break;
            case 'Sunrise':
            case 'Dahwah-e-kubrah':
              jamaatKey = name.toLowerCase();
              break;
            default:
              jamaatKey = name.toLowerCase();
          }

          String jamaatStr = '-';
          if (jamaatTimes != null && jamaatTimes!.containsKey(jamaatKey)) {
            final value = jamaatTimes![jamaatKey];
            if (value != null && value.toString().isNotEmpty) {
              jamaatStr = _formatJamaatTime(value.toString());
            }
          }

          final isCurrent = name == currentPrayerName;
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

  String _formatJamaatTime(String value) {
    value = value.trim();
    if (value.isEmpty) return '-';
    try {
      final time = DateFormat('HH:mm').parseStrict(value);
      return DateFormat('HH:mm').format(time);
    } catch (_) {
      try {
        final time = DateFormat('hh:mm a').parseStrict(value);
        return DateFormat('HH:mm').format(time);
      } catch (_) {
        return '-';
      }
    }
  }
} 