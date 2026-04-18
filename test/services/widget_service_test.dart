import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:jamaat_time/core/app_text.dart';
import 'package:jamaat_time/services/widget_service.dart';
import 'package:jamaat_time/utils/bangla_calendar.dart';
import 'package:flutter/widgets.dart';

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

  Map<String, dynamic> buildJamaatTimes() {
    return {
      'fajr': '05:20',
      'dhuhr': '12:25',
      'asr': '15:55',
      'maghrib': '18:33',
      'isha': '20:00',
    };
  }

  group('WidgetService.computeWidgetPreviewData', () {
    test(
      'between Fajr and Sunrise: current is Fajr, next boundary is Sunrise',
      () {
        final data = WidgetService.computeWidgetPreviewData(
          times: buildTimes(),
          locale: const Locale('en'),
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
        locale: const Locale('en'),
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

    test('bangla locale localizes prayer and row time digits', () {
      final data = WidgetService.computeWidgetPreviewData(
        times: buildTimes(),
        locale: const Locale('bn'),
        now: DateTime(2026, 4, 13, 6, 30),
        timeFormat: DateFormat('HH:mm'),
      );

      expect(data.prayerName, AppText.of(const Locale('bn')).prayer_sunrise);
      expect(data.prayerTime, BanglaCalendar.toBanglaDigits('06:15'));
      expect(data.rowTimes[0], BanglaCalendar.toBanglaDigits('12:10'));
      expect(data.rowTimes[1], BanglaCalendar.toBanglaDigits('15:40'));
    });

    test('active jamaat countdown uses current main prayer label', () {
      final data = WidgetService.computeWidgetPreviewData(
        times: buildTimes(),
        locale: const Locale('en'),
        now: DateTime(2026, 4, 13, 5, 10),
        timeFormat: DateFormat('HH:mm'),
        jamaatTimes: buildJamaatTimes(),
      );

      expect(data.jamaatLabel, 'Fajr Jamaat in');
      expect(data.jamaatCountdownRunning, isTrue);
      expect(
        data.jamaatEpochMillis,
        DateTime(2026, 4, 13, 5, 20).millisecondsSinceEpoch,
      );
    });

    test('sunrise period shows next jamaat countdown (Dhuhr)', () {
      final data = WidgetService.computeWidgetPreviewData(
        times: buildTimes(),
        locale: const Locale('en'),
        now: DateTime(2026, 4, 13, 6, 30),
        timeFormat: DateFormat('HH:mm'),
        jamaatTimes: buildJamaatTimes(),
      );

      expect(data.prayerName, 'Sunrise');
      expect(data.jamaatLabel, 'Dhuhr Jamaat in');
      expect(data.jamaatCountdownRunning, isTrue);
      expect(
        data.jamaatEpochMillis,
        DateTime(2026, 4, 13, 12, 25).millisecondsSinceEpoch,
      );
    });

    test('missing jamaat data shows N/A state', () {
      final data = WidgetService.computeWidgetPreviewData(
        times: buildTimes(),
        locale: const Locale('en'),
        now: DateTime(2026, 4, 13, 5, 10),
        timeFormat: DateFormat('HH:mm'),
      );

      expect(data.jamaatLabel, 'Jamaat N/A');
      expect(data.jamaatCountdownRunning, isFalse);
      expect(data.jamaatEpochMillis, 0);
    });

    test('after Isha: countdown targets tomorrow Fajr', () {
      final tomorrowFajr = DateTime(2026, 4, 14, 5, 1);
      final data = WidgetService.computeWidgetPreviewData(
        times: buildTimes(),
        locale: const Locale('en'),
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
        locale: const Locale('en'),
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
