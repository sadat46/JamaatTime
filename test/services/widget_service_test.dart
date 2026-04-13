import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:jamaat_time/services/widget_service.dart';

void main() {
  Map<String, DateTime?> buildTimes() {
    return {
      'Fajr': DateTime(2026, 4, 13, 5, 0),
      'Sunrise': DateTime(2026, 4, 13, 6, 15),
      'Dhuhr': DateTime(2026, 4, 13, 12, 10),
      'Asr': DateTime(2026, 4, 13, 15, 40),
      'Maghrib': DateTime(2026, 4, 13, 18, 20),
      'Isha': DateTime(2026, 4, 13, 19, 45),
    };
  }

  group('WidgetService.computeWidgetPreviewData', () {
    test(
      'between Fajr and Sunrise: current is Fajr, next boundary is Sunrise',
      () {
        final data = WidgetService.computeWidgetPreviewData(
          times: buildTimes(),
          now: DateTime(2026, 4, 13, 5, 30),
          timeFormat: DateFormat('HH:mm'),
        );

        expect(data.prayerName, 'Fajr');
        expect(data.remainingLabel, 'Fajr Time Remaining');
        expect(
          data.nextPrayerEpochMillis,
          DateTime(2026, 4, 13, 6, 15).millisecondsSinceEpoch,
        );
        expect(data.countdownRunning, isTrue);

        expect(data.rowLabels, ['Dhuhr', 'Asr', 'Maghrib', 'Isha']);
        expect(data.rowTimes, ['12:10', '15:40', '18:20', '19:45']);
      },
    );

    test('between Sunrise and Dhuhr: shows Sunrise and Coming Dhuhr', () {
      final data = WidgetService.computeWidgetPreviewData(
        times: buildTimes(),
        now: DateTime(2026, 4, 13, 6, 30),
        timeFormat: DateFormat('HH:mm'),
      );

      expect(data.prayerName, 'Sunrise');
      expect(data.prayerTime, '06:15');
      expect(data.remainingLabel, 'Coming Dhuhr');
      expect(
        data.nextPrayerEpochMillis,
        DateTime(2026, 4, 13, 12, 10).millisecondsSinceEpoch,
      );
      expect(data.countdownRunning, isTrue);

      // Sunrise is not a row item; row remains main-prayer-only.
      expect(data.rowLabels, ['Dhuhr', 'Asr', 'Maghrib', 'Isha']);
    });

    test('after Isha: countdown targets tomorrow Fajr', () {
      final tomorrowFajr = DateTime(2026, 4, 14, 5, 1);
      final data = WidgetService.computeWidgetPreviewData(
        times: buildTimes(),
        now: DateTime(2026, 4, 13, 23, 0),
        timeFormat: DateFormat('HH:mm'),
        tomorrowFajr: tomorrowFajr,
      );

      expect(data.prayerName, 'Isha');
      expect(data.remainingLabel, 'Isha Time Remaining');
      expect(data.nextPrayerEpochMillis, tomorrowFajr.millisecondsSinceEpoch);
      expect(data.countdownRunning, isTrue);
      expect(data.rowLabels, ['Fajr', 'Dhuhr', 'Asr', 'Maghrib']);
      expect(data.rowTimes, ['05:00', '12:10', '15:40', '18:20']);
    });

    test('after Isha with missing tomorrow Fajr: countdown stops safely', () {
      final data = WidgetService.computeWidgetPreviewData(
        times: buildTimes(),
        now: DateTime(2026, 4, 13, 23, 0),
        timeFormat: DateFormat('HH:mm'),
      );

      expect(data.prayerName, 'Isha');
      expect(data.nextPrayerEpochMillis, 0);
      expect(data.countdownRunning, isFalse);
      expect(data.rowLabels.length, 4);
      expect(data.rowTimes.length, 4);
    });
  });
}
