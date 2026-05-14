import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/app_text.dart';
import '../notification_ids.dart';
import '../notification_localization.dart';
import '../notification_schedule_gateway.dart';
import 'notification_reminder_candidate.dart';

class PrayerEndReminderScheduler {
  PrayerEndReminderScheduler({
    required NotificationScheduleGateway scheduleGateway,
    required Future<Locale> Function() localeResolver,
    required tz.Location Function() locationResolver,
  }) : _scheduleGateway = scheduleGateway,
       _localeResolver = localeResolver,
       _locationResolver = locationResolver;

  final NotificationScheduleGateway _scheduleGateway;
  final Future<Locale> Function() _localeResolver;
  final tz.Location Function() _locationResolver;

  static const Duration reminderOffset = Duration(minutes: 20);

  Future<void> schedule({
    required Map<String, DateTime?> todayPrayerTimes,
    Map<String, DateTime?>? tomorrowPrayerTimes,
  }) async {
    try {
      final locale = await _localeResolver();
      final strings = AppText.of(locale);
      final location = _locationResolver();
      final now = tz.TZDateTime.now(location);

      final candidates = <NotificationReminderCandidate>[
        ...buildCandidatesWithIds(
          todayPrayerTimes,
          idMap: NotificationIds.prayerEndReminders,
          location: location,
          now: now,
        ),
        if (tomorrowPrayerTimes != null)
          ...buildCandidatesWithIds(
            tomorrowPrayerTimes,
            idMap: NotificationIds.prayerEndRemindersTomorrow,
            location: location,
            now: now,
          ),
      ];

      developer.log(
        'JT_NOTIFY prayer_end candidates=${candidates.length}',
        name: 'NotificationService',
      );

      for (final candidate in candidates) {
        final prayerLabel = localizedPrayerName(locale, candidate.prayerKey);
        await _scheduleGateway.scheduleStandard(
          id: candidate.id,
          title: strings.notification_prayerTitle(prayerLabel),
          body: strings.notification_prayerBody(prayerLabel),
          scheduledTime: candidate.scheduledTime,
          notificationType: 'prayer',
        );
      }
    } catch (e) {
      developer.log(
        'Error in schedulePrayerNotifications: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  static Map<String, DateTime?> calculateNotificationTimes(
    Map<String, DateTime?> prayerTimes, {
    required tz.Location location,
  }) {
    try {
      final localPrayerTimes = _localPrayerTimes(prayerTimes, location);
      return _calculateFromLocalPrayerTimes(localPrayerTimes);
    } catch (_) {
      return {};
    }
  }

  static List<NotificationReminderCandidate> buildFutureReminderCandidates(
    Map<String, DateTime?> prayerTimes, {
    required tz.Location location,
    required tz.TZDateTime now,
  }) {
    return buildCandidatesWithIds(
      prayerTimes,
      idMap: NotificationIds.prayerEndReminders,
      location: location,
      now: now,
    );
  }

  static List<NotificationReminderCandidate> buildCandidatesWithIds(
    Map<String, DateTime?> prayerTimes, {
    required Map<String, int> idMap,
    required tz.Location location,
    required tz.TZDateTime now,
  }) {
    final notificationTimes = calculateNotificationTimes(
      prayerTimes,
      location: location,
    );
    final candidates = <NotificationReminderCandidate>[];

    for (final prayerKey in const ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      final notifyTime = notificationTimes[prayerKey];
      final id = idMap[prayerKey];
      if (notifyTime == null || id == null || !notifyTime.isAfter(now)) {
        continue;
      }
      candidates.add(
        NotificationReminderCandidate(
          prayerKey: prayerKey,
          id: id,
          scheduledTime: notifyTime,
        ),
      );
    }

    return candidates;
  }

  static Map<String, tz.TZDateTime> _localPrayerTimes(
    Map<String, DateTime?> prayerTimes,
    tz.Location location,
  ) {
    final localPrayerTimes = <String, tz.TZDateTime>{};
    for (final entry in prayerTimes.entries) {
      if (entry.value != null) {
        localPrayerTimes[entry.key] = tz.TZDateTime.from(
          entry.value!,
          location,
        );
      }
    }
    return localPrayerTimes;
  }

  static Map<String, DateTime?> _calculateFromLocalPrayerTimes(
    Map<String, tz.TZDateTime> localPrayerTimes,
  ) {
    final notificationTimes = <String, DateTime?>{};

    if (localPrayerTimes.containsKey('Fajr') &&
        localPrayerTimes.containsKey('Sunrise')) {
      notificationTimes['Fajr'] = localPrayerTimes['Sunrise']!.subtract(
        reminderOffset,
      );
    }

    if (localPrayerTimes.containsKey('Dhuhr') &&
        localPrayerTimes.containsKey('Asr')) {
      notificationTimes['Dhuhr'] = localPrayerTimes['Asr']!.subtract(
        reminderOffset,
      );
    }

    if (localPrayerTimes.containsKey('Asr') &&
        localPrayerTimes.containsKey('Maghrib')) {
      notificationTimes['Asr'] = localPrayerTimes['Maghrib']!.subtract(
        reminderOffset,
      );
    }

    if (localPrayerTimes.containsKey('Maghrib') &&
        localPrayerTimes.containsKey('Isha')) {
      notificationTimes['Maghrib'] = localPrayerTimes['Isha']!.subtract(
        reminderOffset,
      );
    }

    if (localPrayerTimes.containsKey('Isha') &&
        localPrayerTimes.containsKey('Fajr')) {
      final nextDayFajr = localPrayerTimes['Fajr']!.add(
        const Duration(days: 1),
      );
      notificationTimes['Isha'] = nextDayFajr.subtract(reminderOffset);
    }

    return notificationTimes;
  }
}
