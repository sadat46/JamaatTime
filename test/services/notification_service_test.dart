import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/core/app_text.dart';
import 'package:jamaat_time/services/notifications/notification_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('Bengali prayer title localizes Fajr notification label', () {
    final bn = AppText.of(const Locale('bn'));
    expect(bn.notification_prayerTitle(bn.prayer_fajr), 'ফজর নামাজ');
  });

  test('English prayer title localizes Fajr notification label', () {
    final en = AppText.of(const Locale('en'));
    expect(en.notification_prayerTitle(en.prayer_fajr), 'Fajr Prayer');
  });

  group('nextTahajjudEndFajrStartNotificationTime', () {
    test('uses same-day Fajr when it is still upcoming', () {
      final location = tz.getLocation('Asia/Dhaka');
      final now = tz.TZDateTime(location, 2026, 5, 9, 4, 0);
      final fajr = tz.TZDateTime(location, 2026, 5, 9, 4, 55);

      final scheduled =
          NotificationService.nextTahajjudEndFajrStartNotificationTime(
            fajrTime: fajr,
            now: now,
            location: location,
          );

      expect(scheduled, fajr);
    });

    test('uses next-day Fajr when same-day Fajr already passed', () {
      final location = tz.getLocation('Asia/Dhaka');
      final now = tz.TZDateTime(location, 2026, 5, 9, 5, 1);
      final fajr = tz.TZDateTime(location, 2026, 5, 9, 4, 55);

      final scheduled =
          NotificationService.nextTahajjudEndFajrStartNotificationTime(
            fajrTime: fajr,
            now: now,
            location: location,
          );

      expect(scheduled, tz.TZDateTime(location, 2026, 5, 10, 4, 55));
    });

    test('uses next-day Fajr when current time equals same-day Fajr', () {
      final location = tz.getLocation('Asia/Dhaka');
      final now = tz.TZDateTime(location, 2026, 5, 9, 4, 55);
      final fajr = tz.TZDateTime(location, 2026, 5, 9, 4, 55);

      final scheduled =
          NotificationService.nextTahajjudEndFajrStartNotificationTime(
            fajrTime: fajr,
            now: now,
            location: location,
          );

      expect(scheduled, tz.TZDateTime(location, 2026, 5, 10, 4, 55));
    });
  });
}
