import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/services/notifications/fajr_voice_notification_scheduler.dart';
import 'package:jamaat_time/services/notifications/jamaat_reminder_scheduler.dart';
import 'package:jamaat_time/services/notifications/notification_channel_service.dart';
import 'package:jamaat_time/services/notifications/notification_ids.dart';
import 'package:jamaat_time/services/notifications/prayer_end_reminder_scheduler.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('NotificationIds', () {
    test('keeps stable local notification ranges', () {
      expect(NotificationIds.prayerEndReminders, {
        'Fajr': 1101,
        'Dhuhr': 1102,
        'Asr': 1103,
        'Maghrib': 1104,
        'Isha': 1105,
      });
      expect(NotificationIds.jamaatReminders, {
        'Fajr': 2101,
        'Dhuhr': 2102,
        'Asr': 2103,
        'Maghrib': 2104,
        'Isha': 2105,
      });
      expect(NotificationIds.fajrVoice, 3101);
    });
  });

  group('NotificationChannelService', () {
    test('maps prayer and jamaat sound modes to existing channel ids', () {
      expect(
        NotificationChannelService.prayerChannelId(0),
        'prayer_channel_custom',
      );
      expect(
        NotificationChannelService.prayerChannelId(1),
        'prayer_channel_system',
      );
      expect(
        NotificationChannelService.prayerChannelId(2),
        'prayer_channel_silent',
      );
      expect(
        NotificationChannelService.prayerChannelId(3),
        'prayer_channel_custom_2',
      );
      expect(
        NotificationChannelService.prayerChannelId(4),
        'prayer_channel_custom_3',
      );

      expect(
        NotificationChannelService.jamaatChannelId(0),
        'jamaat_channel_custom',
      );
      expect(
        NotificationChannelService.jamaatChannelId(1),
        'jamaat_channel_system',
      );
      expect(
        NotificationChannelService.jamaatChannelId(2),
        'jamaat_channel_silent',
      );
      expect(
        NotificationChannelService.jamaatChannelId(3),
        'jamaat_channel_custom_2',
      );
      expect(
        NotificationChannelService.jamaatChannelId(4),
        'jamaat_channel_custom_3',
      );
    });

    test('maps custom sounds and silent config', () {
      expect(
        NotificationChannelService.customSoundResource(
          notificationType: 'prayer',
          soundMode: 3,
        ),
        'prayer_custom_2',
      );
      expect(
        NotificationChannelService.customSoundResource(
          notificationType: 'jamaat',
          soundMode: 3,
        ),
        'jamaat_custom_2',
      );
      expect(
        NotificationChannelService.customSoundResource(
          notificationType: 'jamaat',
          soundMode: 2,
        ),
        isNull,
      );

      final silent = NotificationChannelService.notificationConfig(
        notificationType: 'prayer',
        soundMode: 2,
      );
      expect(silent.channelId, 'prayer_channel_silent');
      expect(silent.playSound, isFalse);
      expect(silent.enableVibration, isFalse);
    });
  });

  group('PrayerEndReminderScheduler', () {
    test('builds future prayer-end reminders with 110x ids', () {
      final location = tz.getLocation('Asia/Dhaka');
      final now = tz.TZDateTime(location, 2026, 5, 10, 15, 0);
      final prayerTimes = {
        'Fajr': tz.TZDateTime(location, 2026, 5, 10, 3, 56),
        'Sunrise': tz.TZDateTime(location, 2026, 5, 10, 5, 15),
        'Dhuhr': tz.TZDateTime(location, 2026, 5, 10, 12, 0),
        'Asr': tz.TZDateTime(location, 2026, 5, 10, 16, 31),
        'Maghrib': tz.TZDateTime(location, 2026, 5, 10, 18, 31),
        'Isha': tz.TZDateTime(location, 2026, 5, 10, 19, 51),
      };

      final candidates =
          PrayerEndReminderScheduler.buildFutureReminderCandidates(
            prayerTimes,
            location: location,
            now: now,
          );

      expect(candidates.map((candidate) => candidate.id), [
        1102,
        1103,
        1104,
        1105,
      ]);
      expect(candidates.map((candidate) => candidate.prayerKey), [
        'Dhuhr',
        'Asr',
        'Maghrib',
        'Isha',
      ]);
      expect(
        candidates[0].scheduledTime,
        tz.TZDateTime(location, 2026, 5, 10, 16, 11),
      );
      expect(
        candidates[1].scheduledTime,
        tz.TZDateTime(location, 2026, 5, 10, 18, 11),
      );
      expect(
        candidates[2].scheduledTime,
        tz.TZDateTime(location, 2026, 5, 10, 19, 31),
      );
      expect(
        candidates[3].scheduledTime,
        tz.TZDateTime(location, 2026, 5, 11, 3, 36),
      );
    });
  });

  group('JamaatReminderScheduler', () {
    test('canonicalizes accepted jamaat keys', () {
      expect(
        JamaatReminderScheduler.canonicalPrayerNameFromJamaatKey('fajr'),
        'Fajr',
      );
      expect(
        JamaatReminderScheduler.canonicalPrayerNameFromJamaatKey('zuhr'),
        'Dhuhr',
      );
      expect(
        JamaatReminderScheduler.canonicalPrayerNameFromJamaatKey('magrib'),
        'Maghrib',
      );
    });

    test(
      'builds future jamaat reminders with 210x ids and skips invalid data',
      () {
        final location = tz.getLocation('Asia/Dhaka');
        final now = tz.TZDateTime(location, 2026, 5, 10, 15, 0);
        final jamaatTimes = {
          'fajr': '05:05',
          'zuhr': '16:40',
          'asr': '18:49',
          'magrib': '20:35',
          'isha': '-',
          'unknown': '21:00',
          'bad': '99:99',
        };

        final candidates =
            JamaatReminderScheduler.buildFutureReminderCandidates(
              jamaatTimes,
              location: location,
              now: now,
            );

        expect(candidates.map((candidate) => candidate.id), [2102, 2103, 2104]);
        expect(candidates.map((candidate) => candidate.prayerKey), [
          'Dhuhr',
          'Asr',
          'Maghrib',
        ]);
        expect(
          candidates[0].scheduledTime,
          tz.TZDateTime(location, 2026, 5, 10, 16, 30),
        );
        expect(
          candidates[1].scheduledTime,
          tz.TZDateTime(location, 2026, 5, 10, 18, 39),
        );
        expect(
          candidates[2].scheduledTime,
          tz.TZDateTime(location, 2026, 5, 10, 20, 25),
        );
      },
    );
  });

  group('FajrVoiceNotificationScheduler', () {
    test('rolls same-day Fajr to next day after it has passed', () {
      final location = tz.getLocation('Asia/Dhaka');
      final now = tz.TZDateTime(location, 2026, 5, 10, 5, 0);
      final fajr = tz.TZDateTime(location, 2026, 5, 10, 3, 56);

      final scheduled =
          FajrVoiceNotificationScheduler.nextFajrVoiceNotificationTime(
            fajrTime: fajr,
            now: now,
            location: location,
          );

      expect(scheduled, tz.TZDateTime(location, 2026, 5, 11, 3, 56));
    });
  });
}
