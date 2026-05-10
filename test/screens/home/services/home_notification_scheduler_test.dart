import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/core/app_locale_controller.dart';
import 'package:jamaat_time/models/location_config.dart';
import 'package:jamaat_time/screens/home/services/home_notification_scheduler.dart';
import 'package:jamaat_time/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppLocaleController.bootstrapWithFallback();
  });

  test(
    'runs the latest jamaat schedule after an older no-jamaat request',
    () async {
      final calls = <Map<String, dynamic>?>[];
      final autoVibrationCalls = <Map<String, dynamic>?>[];
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final scheduler = _scheduler(
        onSchedule: (prayerTimes, jamaatTimes) async {
          calls.add(jamaatTimes == null ? null : Map.of(jamaatTimes));
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
        jamaatTimes: null,
        selectedCity: 'Dhaka',
        currentPlaceName: null,
        locationConfig: _serverLocation,
      );
      await firstStarted.future;

      final jamaatTimes = {'dhuhr': '16:40', 'asr': '18:49'};
      final secondSchedule = scheduler.scheduleIfNeeded(
        selectedDate: today,
        prayerTimes: _prayerTimes(today),
        jamaatTimes: jamaatTimes,
        selectedCity: 'Dhaka',
        currentPlaceName: null,
        locationConfig: _serverLocation,
      );

      expect(calls, [null]);
      releaseFirst.complete();
      await Future.wait([firstSchedule, secondSchedule]);

      expect(calls, [null, jamaatTimes]);
      expect(autoVibrationCalls, [jamaatTimes]);
    },
  );

  test(
    'replaces stale pending schedules with the newest jamaat data',
    () async {
      final calls = <Map<String, dynamic>?>[];
      final firstStarted = Completer<void>();
      final releaseFirst = Completer<void>();
      final scheduler = _scheduler(
        onSchedule: (prayerTimes, jamaatTimes) async {
          calls.add(jamaatTimes == null ? null : Map.of(jamaatTimes));
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
        jamaatTimes: null,
        selectedCity: 'Dhaka',
        currentPlaceName: null,
        locationConfig: _serverLocation,
      );
      await firstStarted.future;

      unawaited(
        scheduler.scheduleIfNeeded(
          selectedDate: today,
          prayerTimes: _prayerTimes(today),
          jamaatTimes: {'dhuhr': '16:40'},
          selectedCity: 'Dhaka',
          currentPlaceName: null,
          locationConfig: _serverLocation,
        ),
      );
      final newestJamaatTimes = {'dhuhr': '16:45', 'asr': '18:50'};
      final newestSchedule = scheduler.scheduleIfNeeded(
        selectedDate: today,
        prayerTimes: _prayerTimes(today),
        jamaatTimes: newestJamaatTimes,
        selectedCity: 'Dhaka',
        currentPlaceName: null,
        locationConfig: _serverLocation,
      );

      releaseFirst.complete();
      await Future.wait([firstSchedule, newestSchedule]);

      expect(calls, [null, newestJamaatTimes]);
    },
  );

  test('dedupes the latest completed complete schedule', () async {
    final calls = <Map<String, dynamic>?>[];
    final scheduler = _scheduler(
      onSchedule: (prayerTimes, jamaatTimes) async {
        calls.add(jamaatTimes == null ? null : Map.of(jamaatTimes));
        return true;
      },
    );

    final today = _today();
    final jamaatTimes = {'dhuhr': '16:40', 'asr': '18:49'};

    await scheduler.scheduleIfNeeded(
      selectedDate: today,
      prayerTimes: _prayerTimes(today),
      jamaatTimes: jamaatTimes,
      selectedCity: 'Dhaka',
      currentPlaceName: null,
      locationConfig: _serverLocation,
    );
    await scheduler.scheduleIfNeeded(
      selectedDate: today,
      prayerTimes: _prayerTimes(today),
      jamaatTimes: jamaatTimes,
      selectedCity: 'Dhaka',
      currentPlaceName: null,
      locationConfig: _serverLocation,
    );

    expect(calls, [jamaatTimes]);
  });
}

HomeNotificationScheduler _scheduler({
  required ScheduleAllNotifications onSchedule,
  RescheduleAutoVibration? onAutoVibration,
}) {
  return HomeNotificationScheduler(
    notificationService: NotificationService(),
    scheduleAllNotifications: onSchedule,
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
