import 'package:flutter/material.dart';
import 'package:adhan_dart/adhan_dart.dart';
import '../services/prayer_calculation_service.dart';

/// Widget to display forbidden prayer time windows
class ForbiddenTimesWidget extends StatelessWidget {
  final PrayerTimes? prayerTimes;

  const ForbiddenTimesWidget({
    super.key,
    required this.prayerTimes,
  });

  @override
  Widget build(BuildContext context) {
    if (prayerTimes == null) {
      return const SizedBox.shrink();
    }

    final forbiddenWindows = PrayerCalculationService.instance
        .calculateForbiddenWindows(prayerTimes!);

    if (forbiddenWindows.isEmpty) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0),
          child: Text(
            'Forbidden Prayer Times',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(3),
            2: FlexColumnWidth(2),
          },
          children: [
            // Header Row
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.red.shade900
                    : Colors.red.shade700,
              ),
              children: const [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Window Name',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Time Range',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            // Data Rows
            ...forbiddenWindows.map((window) {
              final isActive = window.isActive(now);
              return TableRow(
                decoration: BoxDecoration(
                  color: isActive
                      ? (Theme.of(context).brightness == Brightness.dark
                          ? Colors.red.shade900.withValues(alpha: 0.4)
                          : Colors.red.shade100)
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.red.shade900.withValues(alpha: 0.2)
                          : Colors.red.shade50),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      window.name,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: Text(
                        window.toRangeString(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: Text(
                        'Makruh',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }
}
