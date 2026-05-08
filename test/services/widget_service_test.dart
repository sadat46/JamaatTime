import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jamaat_time/core/app_text.dart';
import 'package:jamaat_time/services/widget_service.dart';
import 'package:jamaat_time/utils/bangla_calendar.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('bn');
  });

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

  Map<String, DateTime?> buildTomorrowTimes() {
    return {
      'Fajr': DateTime(2026, 4, 14, 5, 1),
      'Sunrise': DateTime(2026, 4, 14, 6, 16),
      'Dhuhr': DateTime(2026, 4, 14, 12, 11),
      'Asr': DateTime(2026, 4, 14, 15, 41),
      'Maghrib': DateTime(2026, 4, 14, 18, 21),
      'Isha': DateTime(2026, 4, 14, 19, 46),
    };
  }

  Map<String, dynamic> buildTomorrowJamaatTimes() {
    return {
      'fajr': '05:21',
      'dhuhr': '12:26',
      'asr': '15:56',
      'maghrib': '18:34',
      'isha': '20:01',
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
          timeFormat: WidgetService.widgetTimeFormatForLocale(
            const Locale('en'),
          ),
        );

        expect(data.prayerName, 'Fajr');
        expect(data.prayerTime, '05:00');
        expect(
          data.prayerTime.contains('AM') || data.prayerTime.contains('PM'),
          isFalse,
        );
        expect(data.remainingLabel, 'Prayer ends in');
        expect(
          data.nextPrayerEpochMillis,
          DateTime(2026, 4, 13, 6, 15).millisecondsSinceEpoch,
        );
        expect(data.countdownRunning, isTrue);

        expect(data.rowLabels, ['Dhuhr', 'Asr', 'Maghrib', 'Isha']);
        expect(data.rowTimes, ['12:10', '15:40', '18:20', '19:45']);
      },
    );

    test(
      'between Sunrise and Dhuhr: shows Sunrise and next prayer countdown',
      () {
        final data = WidgetService.computeWidgetPreviewData(
          times: buildTimes(),
          locale: const Locale('en'),
          now: DateTime(2026, 4, 13, 6, 30),
          timeFormat: WidgetService.widgetTimeFormatForLocale(
            const Locale('en'),
          ),
        );

        expect(data.prayerName, 'Sunrise');
        expect(data.prayerTime, '06:15');
        expect(data.remainingLabel, 'Dhuhr in');
        expect(
          data.nextPrayerEpochMillis,
          DateTime(2026, 4, 13, 12, 10).millisecondsSinceEpoch,
        );
        expect(data.countdownRunning, isTrue);

        // Sunrise is not a row item; row remains main-prayer-only.
        expect(data.rowLabels, ['Dhuhr', 'Asr', 'Maghrib', 'Isha']);
      },
    );

    test('bangla locale localizes prayer and row time digits', () {
      final data = WidgetService.computeWidgetPreviewData(
        times: buildTimes(),
        locale: const Locale('bn'),
        now: DateTime(2026, 4, 13, 6, 30),
        timeFormat: WidgetService.widgetTimeFormatForLocale(const Locale('bn')),
      );

      expect(data.prayerName, AppText.of(const Locale('bn')).prayer_sunrise);
      expect(data.prayerTime, BanglaCalendar.toBanglaDigits('06:15'));
      expect(data.rowTimes[0], BanglaCalendar.toBanglaDigits('12:10'));
      expect(data.rowTimes[1], BanglaCalendar.toBanglaDigits('15:40'));
    });

    test('bangla locale uses updated prayer and jamaat countdown labels', () {
      final data = WidgetService.computeWidgetPreviewData(
        times: buildTimes(),
        locale: const Locale('bn'),
        now: DateTime(2026, 4, 13, 5, 10),
        timeFormat: WidgetService.widgetTimeFormatForLocale(const Locale('bn')),
        jamaatTimes: buildJamaatTimes(),
      );

      expect(data.remainingLabel, 'ওয়াক্ত শেষ হতে বাকি');
      expect(data.jamaatLabel, 'জামাত শুরু হতে বাকি');
      expect(data.jamaatCountdownRunning, isTrue);
    });

    test('before jamaat: shows jamaat in countdown', () {
      final data = WidgetService.computeWidgetPreviewData(
        times: buildTimes(),
        locale: const Locale('en'),
        now: DateTime(2026, 4, 13, 5, 10),
        timeFormat: WidgetService.widgetTimeFormatForLocale(const Locale('en')),
        jamaatTimes: buildJamaatTimes(),
      );

      expect(data.jamaatLabel, 'Jamaat in');
      expect(data.jamaatValueText, '');
      expect(data.jamaatCountdownRunning, isTrue);
      expect(data.jamaatTextUsesTimeStyle, isFalse);
      expect(
        data.jamaatEpochMillis,
        DateTime(2026, 4, 13, 5, 20).millisecondsSinceEpoch,
      );
      expect(
        data.jamaatOverEpochMillis,
        DateTime(2026, 4, 13, 5, 30).millisecondsSinceEpoch,
      );
    });

    test('during jamaat: shows jamaat ongoing without countdown', () {
      final data = WidgetService.computeWidgetPreviewData(
        times: buildTimes(),
        locale: const Locale('en'),
        now: DateTime(2026, 4, 13, 5, 25),
        timeFormat: WidgetService.widgetTimeFormatForLocale(const Locale('en')),
        jamaatTimes: buildJamaatTimes(),
      );

      expect(data.jamaatLabel, 'Jamaat');
      expect(data.jamaatValueText, 'ongoing');
      expect(data.jamaatCountdownRunning, isFalse);
      expect(data.jamaatTextUsesTimeStyle, isTrue);
      expect(data.jamaatEpochMillis, 0);
      expect(data.jamaatOverEpochMillis, 0);
    });

    test('after jamaat: shows jamaat ended', () {
      final data = WidgetService.computeWidgetPreviewData(
        times: buildTimes(),
        locale: const Locale('en'),
        now: DateTime(2026, 4, 13, 5, 31),
        timeFormat: WidgetService.widgetTimeFormatForLocale(const Locale('en')),
        jamaatTimes: buildJamaatTimes(),
      );

      expect(data.jamaatLabel, 'Jamaat');
      expect(data.jamaatValueText, 'ended');
      expect(data.jamaatCountdownRunning, isFalse);
      expect(data.jamaatTextUsesTimeStyle, isTrue);
      expect(data.jamaatEpochMillis, 0);
      expect(data.jamaatOverEpochMillis, 0);
    });

    test('sunrise period shows next jamaat static time line', () {
      final data = WidgetService.computeWidgetPreviewData(
        times: buildTimes(),
        locale: const Locale('en'),
        now: DateTime(2026, 4, 13, 6, 30),
        timeFormat: WidgetService.widgetTimeFormatForLocale(const Locale('en')),
        jamaatTimes: buildJamaatTimes(),
      );

      expect(data.prayerName, 'Sunrise');
      expect(data.jamaatLabel, 'Dhuhr Jamaat at 12:25');
      expect(
        data.jamaatLabel.contains('AM') || data.jamaatLabel.contains('PM'),
        isFalse,
      );
      expect(data.jamaatValueText, '');
      expect(data.jamaatCountdownRunning, isFalse);
      expect(data.jamaatTextUsesTimeStyle, isFalse);
      expect(data.jamaatEpochMillis, 0);
    });

    test('missing jamaat data shows N/A state', () {
      final data = WidgetService.computeWidgetPreviewData(
        times: buildTimes(),
        locale: const Locale('en'),
        now: DateTime(2026, 4, 13, 5, 10),
        timeFormat: WidgetService.widgetTimeFormatForLocale(const Locale('en')),
      );

      expect(data.jamaatLabel, 'Jamaat N/A');
      expect(data.jamaatValueText, '');
      expect(data.jamaatCountdownRunning, isFalse);
      expect(data.jamaatTextUsesTimeStyle, isFalse);
      expect(data.jamaatEpochMillis, 0);
    });

    test('after Isha: countdown targets tomorrow Fajr', () {
      final tomorrowFajr = DateTime(2026, 4, 14, 5, 1);
      final data = WidgetService.computeWidgetPreviewData(
        times: buildTimes(),
        locale: const Locale('en'),
        now: DateTime(2026, 4, 13, 23, 0),
        timeFormat: WidgetService.widgetTimeFormatForLocale(const Locale('en')),
        tomorrowFajr: tomorrowFajr,
      );

      expect(data.prayerName, 'Isha');
      expect(data.remainingLabel, 'Prayer ends in');
      expect(data.nextPrayerEpochMillis, tomorrowFajr.millisecondsSinceEpoch);
      expect(data.countdownRunning, isTrue);
      expect(data.rowLabels, ['Fajr', 'Dhuhr', 'Asr', 'Maghrib']);
      expect(data.rowTimes, ['05:00', '12:10', '15:40', '18:20']);
    });

    test(
      'after midnight before Fajr keeps Isha state text and no jamaat countdown',
      () {
        final data = WidgetService.computeWidgetPreviewData(
          times: {
            'Fajr': DateTime(2026, 4, 14, 5, 0),
            'Sunrise': DateTime(2026, 4, 14, 6, 15),
            'Dhuhr': DateTime(2026, 4, 14, 12, 10),
            'Asr': DateTime(2026, 4, 14, 15, 40),
            'Maghrib': DateTime(2026, 4, 14, 18, 20),
            'Isha': DateTime(2026, 4, 14, 19, 45),
          },
          locale: const Locale('en'),
          now: DateTime(2026, 4, 14, 0, 30),
          timeFormat: WidgetService.widgetTimeFormatForLocale(
            const Locale('en'),
          ),
          jamaatTimes: buildJamaatTimes(),
        );

        expect(data.prayerName, 'Isha');
        expect(data.remainingLabel, 'Prayer ends in');
        expect(
          data.nextPrayerEpochMillis,
          DateTime(2026, 4, 14, 5, 0).millisecondsSinceEpoch,
        );
        expect(data.countdownRunning, isTrue);
        expect(data.jamaatLabel, 'Jamaat');
        expect(data.jamaatValueText, 'ended');
        expect(data.jamaatCountdownRunning, isFalse);
        expect(data.jamaatTextUsesTimeStyle, isTrue);
        expect(data.jamaatEpochMillis, 0);
      },
    );

    test('after Isha with missing tomorrow Fajr: countdown stops safely', () {
      final data = WidgetService.computeWidgetPreviewData(
        times: buildTimes(),
        locale: const Locale('en'),
        now: DateTime(2026, 4, 13, 23, 0),
        timeFormat: WidgetService.widgetTimeFormatForLocale(const Locale('en')),
      );

      expect(data.prayerName, 'Isha');
      expect(data.nextPrayerEpochMillis, 0);
      expect(data.countdownRunning, isFalse);
      expect(data.rowLabels.length, 4);
      expect(data.rowTimes.length, 4);
    });
  });

  group('WidgetService.resolveTodayJamaatTime', () {
    test('returns parsed DateTime for known prayer key', () {
      final now = DateTime(2026, 4, 13, 12, 0);
      final result = WidgetService.resolveTodayJamaatTime(
        now: now,
        prayerName: 'Dhuhr',
        jamaatTimes: buildJamaatTimes(),
      );
      expect(result, DateTime(2026, 4, 13, 12, 25));
    });

    test('returns null for missing jamaat data', () {
      final now = DateTime(2026, 4, 13, 12, 0);
      final result = WidgetService.resolveTodayJamaatTime(
        now: now,
        prayerName: 'Dhuhr',
        jamaatTimes: null,
      );
      expect(result, isNull);
    });
  });

  group('WidgetService.updateWidgetData payload', () {
    late TestDefaultBinaryMessenger messenger;
    late Map<String, Object?> capturedSaves;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      capturedSaves = <String, Object?>{};
      messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(const MethodChannel('home_widget'), (
        MethodCall call,
      ) async {
        if (call.method == 'saveWidgetData') {
          final args = call.arguments as Map?;
          if (args != null) {
            capturedSaves[args['id'] as String] = args['data'];
          }
          return true;
        }
        if (call.method == 'updateWidget') {
          return true;
        }
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(
        const MethodChannel('home_widget'),
        null,
      );
    });

    test('writes raw epoch + localization keys (en)', () async {
      final tomorrowFajr = DateTime(2026, 4, 14, 5, 1);
      final tomorrowTimes = buildTomorrowTimes();
      final tomorrowJamaatTimes = buildTomorrowJamaatTimes();
      final dayAfterTomorrowFajr = DateTime(2026, 4, 15, 5, 2);
      await WidgetService.updateWidgetData(
        times: buildTimes(),
        locale: const Locale('en'),
        locationName: 'Dhaka',
        date: DateTime(2026, 4, 13, 8, 30),
        hijriOffsetDays: 0,
        tomorrowFajr: tomorrowFajr,
        tomorrowTimes: tomorrowTimes,
        tomorrowJamaatTimes: tomorrowJamaatTimes,
        dayAfterTomorrowFajr: dayAfterTomorrowFajr,
        jamaatTimes: buildJamaatTimes(),
      );

      expect(
        capturedSaves['epoch_fajr_today'],
        DateTime(2026, 4, 13, 5, 0).millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['epoch_sunrise_today'],
        DateTime(2026, 4, 13, 6, 15).millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['epoch_dhuhr_today'],
        DateTime(2026, 4, 13, 12, 10).millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['epoch_isha_today'],
        DateTime(2026, 4, 13, 19, 45).millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['epoch_fajr_tomorrow'],
        tomorrowFajr.millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['epoch_sunrise_tomorrow'],
        DateTime(2026, 4, 14, 6, 16).millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['epoch_dhuhr_tomorrow'],
        DateTime(2026, 4, 14, 12, 11).millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['epoch_asr_tomorrow'],
        DateTime(2026, 4, 14, 15, 41).millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['epoch_maghrib_tomorrow'],
        DateTime(2026, 4, 14, 18, 21).millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['epoch_isha_tomorrow'],
        DateTime(2026, 4, 14, 19, 46).millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['epoch_fajr_day_after_tomorrow'],
        dayAfterTomorrowFajr.millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['jamaat_epoch_dhuhr_today'],
        DateTime(2026, 4, 13, 12, 25).millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['jamaat_epoch_fajr_today'],
        DateTime(2026, 4, 13, 5, 20).millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['jamaat_epoch_fajr_tomorrow'],
        DateTime(2026, 4, 14, 5, 21).millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['jamaat_epoch_dhuhr_tomorrow'],
        DateTime(2026, 4, 14, 12, 26).millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['jamaat_epoch_asr_tomorrow'],
        DateTime(2026, 4, 14, 15, 56).millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['jamaat_epoch_maghrib_tomorrow'],
        DateTime(2026, 4, 14, 18, 34).millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['jamaat_epoch_isha_tomorrow'],
        DateTime(2026, 4, 14, 20, 1).millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['last_compute_day_epoch'],
        DateTime(2026, 4, 13).millisecondsSinceEpoch,
      );
      expect(
        capturedSaves['next_compute_day_epoch'],
        DateTime(2026, 4, 14).millisecondsSinceEpoch,
      );

      expect(capturedSaves['loc_prayer_fajr'], 'Fajr');
      expect(capturedSaves['loc_prayer_dhuhr'], 'Dhuhr');
      expect(capturedSaves['loc_jamaat_in_suffix'], 'Jamaat in');
      expect(capturedSaves['loc_jamaat_ongoing'], 'Jamaat ongoing');
      expect(capturedSaves['loc_jamaat_over'], 'Jamaat ended');
      expect(capturedSaves['loc_jamaat_na'], 'Jamaat N/A');
      expect(capturedSaves['loc_prayer_ends_in'], 'Prayer ends in');
      expect(capturedSaves['loc_next_prayer_in_template'], '{0} in');
      expect(
        capturedSaves['loc_next_prayer_jamaat_template'],
        '{0} Jamaat at {1}',
      );
      expect(capturedSaves['time_format_pattern'], 'HH:mm');
      expect(capturedSaves['locale_code'], 'en');
    });

    test('writes Bangla localization templates', () async {
      await WidgetService.updateWidgetData(
        times: buildTimes(),
        locale: const Locale('bn'),
        locationName: 'Dhaka',
        date: DateTime(2026, 4, 13, 8, 30),
        hijriOffsetDays: 0,
        tomorrowFajr: DateTime(2026, 4, 14, 5, 1),
        jamaatTimes: buildJamaatTimes(),
      );

      expect(capturedSaves['loc_next_prayer_in_template'], '{0} শুরু হবে');
      expect(capturedSaves['loc_next_prayer_jamaat_template'], '{0} জামাত {1}');
      expect(
        (capturedSaves['loc_next_prayer_jamaat_template'] as String).contains(
          '{0}',
        ),
        isTrue,
      );
      expect(
        (capturedSaves['loc_next_prayer_jamaat_template'] as String).contains(
          '{1}',
        ),
        isTrue,
      );
      expect(capturedSaves['locale_code'], 'bn');
    });

    test('writes 0 for missing jamaat entries', () async {
      await WidgetService.updateWidgetData(
        times: buildTimes(),
        locale: const Locale('en'),
        locationName: 'Dhaka',
        date: DateTime(2026, 4, 13, 8, 30),
        hijriOffsetDays: 0,
      );

      expect(capturedSaves['jamaat_epoch_dhuhr_today'], 0);
      expect(capturedSaves['jamaat_epoch_fajr_today'], 0);
      expect(capturedSaves['epoch_fajr_tomorrow'], 0);
      expect(capturedSaves['epoch_sunrise_tomorrow'], 0);
      expect(capturedSaves['jamaat_epoch_fajr_tomorrow'], 0);
      expect(
        capturedSaves['next_compute_day_epoch'],
        DateTime(2026, 4, 14).millisecondsSinceEpoch,
      );
    });
  });
}
