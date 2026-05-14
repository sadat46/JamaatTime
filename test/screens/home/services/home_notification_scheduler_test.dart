import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/core/app_locale_controller.dart';
import 'package:jamaat_time/models/location_config.dart';
import 'package:jamaat_time/screens/home/services/home_notification_scheduler.dart';
import 'package:jamaat_time/services/notifications/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppLocaleController.bootstrapWithFallback();
  });

  test(
    'runs the latest schedule after invalidate from a fresh fetch',
    () async {
      final calls = <Map<String, DateTime?>>[];
      final autoVibrationCalls = <Map<String, dynamic>?>[];
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final scheduler = _scheduler(
        onSchedule:
            ({
              required Map<String, DateTime?> todayPrayerTimes,
              Map<String, DateTime?>? tomorrowPrayerTimes,
              Map<String, dynamic>? todayJamaatTimes,
              Map<String, dynamic>? tomorrowJamaatTimes,
            }) async {
              calls.add(Map.of(todayPrayerTimes));
              if (calls.length == 1) {
                firstStarted.complete();
                await releaseFirst.future;
              }
              return true;
            },
        onAutoVibration: (jamaatTimes) async {
          autoVibrationCalls.add(
            jamaatTimes == null ? null : Map<String, dynamic>.of(jamaatTimes),
          );
        },
      );

      final today = _today();
      final firstSchedule = scheduler.scheduleIfNeeded(
        selectedDate: today,
        prayerTimes: _prayerTimes(today),
        tomorrowPrayerTimes: null,
        jamaatTimes: null,
        selectedCity: 'Dhaka',
        currentPlaceName: null,
        locationConfig: _serverLocation,
      );
      await firstStarted.future;

      // Simulate fetchJamaatTimes() success path: cache is fresh, invalidate
      // forces the next schedule call to execute even with same scheduleKey
      // basis (prayer times unchanged).
      scheduler.invalidate();
      final secondJamaat = {'dhuhr': '16:40', 'asr': '18:49'};
      final secondSchedule = scheduler.scheduleIfNeeded(
        selectedDate: today,
        prayerTimes: _prayerTimes(today),
        tomorrowPrayerTimes: null,
        jamaatTimes: secondJamaat,
        selectedCity: 'Dhaka',
        currentPlaceName: null,
        locationConfig: _serverLocation,
      );

      expect(calls.length, 1);
      releaseFirst.complete();
      await Future.wait([firstSchedule, secondSchedule]);

      expect(calls.length, 2);
      expect(autoVibrationCalls, [secondJamaat]);
    },
  );

  test(
    'collapses pending schedules to the newest invalidated request',
    () async {
      final calls = <Map<String, DateTime?>>[];
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final scheduler = _scheduler(
        onSchedule:
            ({
              required Map<String, DateTime?> todayPrayerTimes,
              Map<String, DateTime?>? tomorrowPrayerTimes,
              Map<String, dynamic>? todayJamaatTimes,
              Map<String, dynamic>? tomorrowJamaatTimes,
            }) async {
              calls.add(Map.of(todayPrayerTimes));
              if (calls.length == 1) {
                firstStarted.complete();
                await releaseFirst.future;
              }
              return true;
            },
      );

      final today = _today();
      final firstSchedule = scheduler.scheduleIfNeeded(
        selectedDate: today,
        prayerTimes: _prayerTimes(today),
        tomorrowPrayerTimes: null,
        jamaatTimes: null,
        selectedCity: 'Dhaka',
        currentPlaceName: null,
        locationConfig: _serverLocation,
      );
      await firstStarted.future;

      // First pending invalidation.
      scheduler.invalidate();
      unawaited(
        scheduler.scheduleIfNeeded(
          selectedDate: today,
          prayerTimes: _prayerTimes(today),
          tomorrowPrayerTimes: null,
          jamaatTimes: {'dhuhr': '16:40'},
          selectedCity: 'Dhaka',
          currentPlaceName: null,
          locationConfig: _serverLocation,
        ),
      );
      // Newer invalidation overrides the previous pending request, since both
      // share the same schedule key but the newest jamaatTimes wins for the
      // auto-vibration callback.
      scheduler.invalidate();
      final newestJamaat = {'dhuhr': '16:45', 'asr': '18:50'};
      final newestSchedule = scheduler.scheduleIfNeeded(
        selectedDate: today,
        prayerTimes: _prayerTimes(today),
        tomorrowPrayerTimes: null,
        jamaatTimes: newestJamaat,
        selectedCity: 'Dhaka',
        currentPlaceName: null,
        locationConfig: _serverLocation,
      );

      releaseFirst.complete();
      await Future.wait([firstSchedule, newestSchedule]);

      // Two scheduleAllNotifications calls: the original in-flight one and
      // exactly one replay from the collapsed pending queue.
      expect(calls.length, 2);
    },
  );

  test('dedupes identical schedule requests', () async {
    final calls = <Map<String, DateTime?>>[];
    final scheduler = _scheduler(
      onSchedule:
          ({
            required Map<String, DateTime?> todayPrayerTimes,
            Map<String, DateTime?>? tomorrowPrayerTimes,
            Map<String, dynamic>? todayJamaatTimes,
            Map<String, dynamic>? tomorrowJamaatTimes,
          }) async {
            calls.add(Map.of(todayPrayerTimes));
            return true;
          },
    );

    final today = _today();
    final prayerTimes = _prayerTimes(today);

    await scheduler.scheduleIfNeeded(
      selectedDate: today,
      prayerTimes: prayerTimes,
      tomorrowPrayerTimes: null,
      jamaatTimes: {'dhuhr': '16:40'},
      selectedCity: 'Dhaka',
      currentPlaceName: null,
      locationConfig: _serverLocation,
    );
    await scheduler.scheduleIfNeeded(
      selectedDate: today,
      prayerTimes: prayerTimes,
      tomorrowPrayerTimes: null,
      jamaatTimes: {'dhuhr': '16:40'},
      selectedCity: 'Dhaka',
      currentPlaceName: null,
      locationConfig: _serverLocation,
    );

    expect(calls.length, 1);
  });

  test('passes jamaat maps to notification scheduling', () async {
    Map<String, dynamic>? capturedTodayJamaat;
    Map<String, dynamic>? capturedTomorrowJamaat;
    final scheduler = _scheduler(
      onSchedule:
          ({
            required Map<String, DateTime?> todayPrayerTimes,
            Map<String, DateTime?>? tomorrowPrayerTimes,
            Map<String, dynamic>? todayJamaatTimes,
            Map<String, dynamic>? tomorrowJamaatTimes,
          }) async {
            capturedTodayJamaat = todayJamaatTimes;
            capturedTomorrowJamaat = tomorrowJamaatTimes;
            return true;
          },
    );

    final today = _today();
    final todayJamaat = {'fajr': '04:55'};
    final tomorrowJamaat = {'fajr': '04:56'};

    await scheduler.scheduleIfNeeded(
      selectedDate: today,
      prayerTimes: _prayerTimes(today),
      tomorrowPrayerTimes: _prayerTimes(today.add(const Duration(days: 1))),
      jamaatTimes: todayJamaat,
      tomorrowJamaatTimes: tomorrowJamaat,
      selectedCity: 'Dhaka',
      currentPlaceName: null,
      locationConfig: _serverLocation,
    );

    expect(capturedTodayJamaat, todayJamaat);
    expect(capturedTomorrowJamaat, tomorrowJamaat);
  });
}

HomeNotificationScheduler _scheduler({
  required ScheduleAllNotifications onSchedule,
  RescheduleAutoVibration? onAutoVibration,
  ScheduleJamaatNotifications? onScheduleJamaat,
}) {
  return HomeNotificationScheduler(
    notificationService: NotificationService(),
    scheduleAllNotifications: onSchedule,
    scheduleJamaatNotifications:
        onScheduleJamaat ?? ({todayJamaatTimes, tomorrowJamaatTimes}) async {},
    rescheduleAutoVibration: onAutoVibration ?? (_) async {},
  );
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

Map<String, DateTime?> _prayerTimes(DateTime day) {
  return {
    'Fajr': DateTime(day.year, day.month, day.day, 4),
    'Sunrise': DateTime(day.year, day.month, day.day, 5, 15),
    'Dhuhr': DateTime(day.year, day.month, day.day, 12),
    'Asr': DateTime(day.year, day.month, day.day, 16, 30),
    'Maghrib': DateTime(day.year, day.month, day.day, 18, 30),
    'Isha': DateTime(day.year, day.month, day.day, 19, 50),
  };
}

const _serverLocation = LocationConfig(
  cityName: 'Dhaka',
  country: Country.bangladesh,
  timezone: 'Asia/Dhaka',
  calculationMethodType: PrayerCalculationMethodType.muslimWorldLeague,
  jamaatSource: JamaatSource.server,
  latitude: 23.8103,
  longitude: 90.4125,
);
