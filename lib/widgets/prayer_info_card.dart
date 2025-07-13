import 'package:flutter/material.dart';
import '../services/widget_service.dart';

class PrayerInfoCard extends StatelessWidget {
  final String currentPrayerName;
  final String currentPrayerTime;
  final String remainingTime;
  final Map<String, String> prayerTimes; // e.g. {'Fajr': '03:55 AM', ...}
  final String islamicDate;
  final String location;

  const PrayerInfoCard({
    super.key,
    required this.currentPrayerName,
    required this.currentPrayerTime,
    required this.remainingTime,
    required this.prayerTimes,
    required this.islamicDate,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentPrayerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentPrayerTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Remaining Time of',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    currentPrayerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        remainingTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: () {
                            WidgetService.updatePrayerWidget(
                              currentPrayerName: currentPrayerName,
                              currentPrayerTime: currentPrayerTime,
                              remainingLabel:
                                  'Remaining Time of $currentPrayerName',
                              remainingTime: remainingTime,
                              fajrTime: prayerTimes['Fajr'] ?? '',
                              asrTime: prayerTimes['Asr'] ?? '',
                              maghribTime: prayerTimes['Maghrib'] ?? '',
                              ishaTime: prayerTimes['Isha'] ?? '',
                              islamicDate: islamicDate,
                              location: location,
                            );
                          }, // You can add refresh logic
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.bug_report, color: Colors.white),
                          onPressed: () {
                            WidgetService.testWidgetData();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var entry in prayerTimes.entries)
                Column(
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.mosque, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                islamicDate,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white70, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
