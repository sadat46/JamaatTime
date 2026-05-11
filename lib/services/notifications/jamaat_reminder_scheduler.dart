import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/app_text.dart';
import 'notification_ids.dart';
import 'notification_localization.dart';
import 'notification_reminder_candidate.dart';
import 'notification_schedule_gateway.dart';

class JamaatReminderScheduler {
  JamaatReminderScheduler({
    required NotificationScheduleGateway scheduleGateway,
    required Future<Locale> Function() localeResolver,
    required tz.Location Function() locationResolver,
  }) : _scheduleGateway = scheduleGateway,
       _localeResolver = localeResolver,
       _locationResolver = locationResolver;

  final NotificationScheduleGateway _scheduleGateway;
  final Future<Locale> Function() _localeResolver;
  final tz.Location Function() _locationResolver;

  static const Duration reminderOffset = Duration(minutes: 10);

  Future<void> schedule(Map<String, dynamic>? jamaatTimes) async {
    try {
      final locale = await _localeResolver();
      final strings = AppText.of(locale);
      final location = _locationResolver();
      final now = tz.TZDateTime.now(location);
      final candidates = buildFutureReminderCandidates(
        jamaatTimes,
        location: location,
        now: now,
      );
      developer.log(
        'JT_NOTIFY jamaat_reminder candidates=${candidates.length}',
        name: 'NotificationService',
      );

      for (final candidate in candidates) {
        try {
          final displayName = localizedPrayerName(locale, candidate.prayerKey);
          await _scheduleGateway.scheduleStandard(
            id: candidate.id,
            title: strings.notification_jamaatTitle(displayName),
            body: strings.notification_jamaatBody(displayName),
            scheduledTime: candidate.scheduledTime,
            notificationType: 'jamaat',
          );
        } catch (e) {
          developer.log(
            'JT_NOTIFY jamaat_reminder error id=${candidate.id} prayer=${candidate.prayerKey} $e',
            name: 'NotificationService',
            error: e,
          );
        }
      }
    } catch (e) {
      developer.log(
        'Error in scheduleJamaatNotifications: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  static Map<String, DateTime?> calculateNotificationTimes(
    Map<String, dynamic>? jamaatTimes, {
    required tz.Location location,
    tz.TZDateTime? now,
  }) {
    try {
      final resolvedNow = now ?? tz.TZDateTime.now(location);
      final notificationTimes = <String, DateTime?>{};

      if (jamaatTimes == null) {
        return notificationTimes;
      }

      for (final entry in jamaatTimes.entries) {
        final parsed = _parse(entry.key, entry.value, location, resolvedNow);
        if (parsed == null) continue;
        notificationTimes[entry.key] = DateTime(
          parsed.notifyTime.year,
          parsed.notifyTime.month,
          parsed.notifyTime.day,
          parsed.notifyTime.hour,
          parsed.notifyTime.minute,
        );
      }

      return notificationTimes;
    } catch (e) {
      developer.log(
        'Error in calculateJamaatNotificationTimes: $e',
        name: 'NotificationService',
        error: e,
      );
      return {};
    }
  }

  static List<NotificationReminderCandidate> buildFutureReminderCandidates(
    Map<String, dynamic>? jamaatTimes, {
    required tz.Location location,
    required tz.TZDateTime now,
  }) {
    final candidates = <NotificationReminderCandidate>[];
    if (jamaatTimes == null || jamaatTimes.isEmpty) {
      developer.log(
        'JT_NOTIFY jamaat_reminder skipped reason=no_jamaat_times',
        name: 'NotificationService',
      );
      return candidates;
    }

    for (final entry in jamaatTimes.entries) {
      final canonicalPrayerName = canonicalPrayerNameFromJamaatKey(entry.key);
      final id = NotificationIds.jamaatReminders[canonicalPrayerName];
      if (id == null) {
        developer.log(
          'JT_NOTIFY skipped jamaat=${entry.key} reason=unknown_prayer_key',
          name: 'NotificationService',
        );
        continue;
      }

      final parsed = _parse(entry.key, entry.value, location, now);
      if (parsed == null || !parsed.notifyTime.isAfter(now)) {
        continue;
      }

      candidates.add(
        NotificationReminderCandidate(
          prayerKey: canonicalPrayerName,
          id: id,
          scheduledTime: parsed.notifyTime,
        ),
      );
    }

    candidates.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return candidates;
  }

  static String canonicalPrayerNameFromJamaatKey(String key) {
    switch (key.toLowerCase()) {
      case 'fajr':
        return 'Fajr';
      case 'dhuhr':
      case 'zuhr':
        return 'Dhuhr';
      case 'asr':
        return 'Asr';
      case 'maghrib':
      case 'magrib':
        return 'Maghrib';
      case 'isha':
        return 'Isha';
      default:
        return key;
    }
  }

  static _ParsedJamaatReminder? _parse(
    String name,
    dynamic value,
    tz.Location location,
    tz.TZDateTime now,
  ) {
    if (value is! String || value.isEmpty || value == '-') {
      return null;
    }

    try {
      final parts = value.split(':');
      if (parts.length != 2) {
        developer.log(
          'Invalid jamaat time format for $name: "$value" (expected HH:mm)',
          name: 'NotificationService',
        );
        return null;
      }

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);

      if (hour == null || minute == null) {
        developer.log(
          'Failed to parse time components for $name: "$value"',
          name: 'NotificationService',
        );
        return null;
      }

      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        developer.log(
          'Time out of range for $name: hour=$hour, minute=$minute',
          name: 'NotificationService',
        );
        return null;
      }

      final jamaatTime = tz.TZDateTime(
        location,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );
      var notifyTime = jamaatTime.subtract(reminderOffset);
      if (!notifyTime.isAfter(now)) {
        notifyTime = notifyTime.add(const Duration(days: 1));
      }

      return _ParsedJamaatReminder(notifyTime: notifyTime);
    } catch (e) {
      developer.log(
        'Error parsing jamaat time for $name: "$value" - $e',
        name: 'NotificationService',
        error: e,
      );
      return null;
    }
  }
}

class _ParsedJamaatReminder {
  const _ParsedJamaatReminder({required this.notifyTime});

  final tz.TZDateTime notifyTime;
}
