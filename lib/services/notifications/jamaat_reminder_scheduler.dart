import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/app_text.dart';
import 'jamaat_schedule_cache.dart';
import 'notification_ids.dart';
import 'notification_localization.dart';
import 'notification_reminder_candidate.dart';
import 'notification_schedule_gateway.dart';

class JamaatReminderScheduler {
  JamaatReminderScheduler({
    required NotificationScheduleGateway scheduleGateway,
    required Future<Locale> Function() localeResolver,
    required tz.Location Function() locationResolver,
    JamaatScheduleCache? cache,
  }) : _scheduleGateway = scheduleGateway,
       _localeResolver = localeResolver,
       _locationResolver = locationResolver,
       _cache = cache ?? JamaatScheduleCache.instance;

  final NotificationScheduleGateway _scheduleGateway;
  final Future<Locale> Function() _localeResolver;
  final tz.Location Function() _locationResolver;
  final JamaatScheduleCache _cache;

  static const Duration reminderOffset = Duration(minutes: 10);

  /// Read today's + tomorrow's jamaat times from the persistent cache and arm
  /// reminders for both date ranges. The home controller is responsible for
  /// keeping the cache fresh.
  Future<void> schedule() async {
    try {
      final locale = await _localeResolver();
      final strings = AppText.of(locale);
      final location = _locationResolver();
      final now = tz.TZDateTime.now(location);
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      final todayTimes = await _cache.readFor(today);
      final tomorrowTimes = await _cache.readFor(tomorrow);

      final candidates = <NotificationReminderCandidate>[
        ...buildCandidatesForDate(
          todayTimes,
          location: location,
          now: now,
          targetDate: today,
          idMap: NotificationIds.jamaatReminders,
        ),
        ...buildCandidatesForDate(
          tomorrowTimes,
          location: location,
          now: now,
          targetDate: tomorrow,
          idMap: NotificationIds.jamaatRemindersTomorrow,
        ),
      ];

      developer.log(
        'JT_NOTIFY jamaat_reminder candidates=${candidates.length} '
        'today=${todayTimes != null} tomorrow=${tomorrowTimes != null}',
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
        final parsed = _parseWithRollover(
          entry.key,
          entry.value,
          location,
          resolvedNow,
        );
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

  /// Legacy helper kept for tests: builds candidates from a single map,
  /// rolling past entries to the next day. Production scheduling now goes
  /// through [buildCandidatesForDate] for today/tomorrow explicitly.
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

      final parsed = _parseWithRollover(entry.key, entry.value, location, now);
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

  /// Build candidates for a specific target date using the supplied [idMap].
  /// No rollover — entries whose notify time falls in the past relative to
  /// [now] are simply dropped.
  static List<NotificationReminderCandidate> buildCandidatesForDate(
    Map<String, dynamic>? jamaatTimes, {
    required tz.Location location,
    required tz.TZDateTime now,
    required DateTime targetDate,
    required Map<String, int> idMap,
  }) {
    final candidates = <NotificationReminderCandidate>[];
    if (jamaatTimes == null || jamaatTimes.isEmpty) return candidates;

    for (final entry in jamaatTimes.entries) {
      final canonicalPrayerName = canonicalPrayerNameFromJamaatKey(entry.key);
      final id = idMap[canonicalPrayerName];
      if (id == null) continue;

      final parsed = _parseForDate(
        entry.key,
        entry.value,
        location,
        targetDate,
      );
      if (parsed == null || !parsed.notifyTime.isAfter(now)) continue;

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

  static _ParsedJamaatReminder? _parseWithRollover(
    String name,
    dynamic value,
    tz.Location location,
    tz.TZDateTime now,
  ) {
    final hm = _parseHourMinute(name, value);
    if (hm == null) return null;
    final jamaatTime = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hm.hour,
      hm.minute,
    );
    var notifyTime = jamaatTime.subtract(reminderOffset);
    if (!notifyTime.isAfter(now)) {
      notifyTime = notifyTime.add(const Duration(days: 1));
    }
    return _ParsedJamaatReminder(notifyTime: notifyTime);
  }

  static _ParsedJamaatReminder? _parseForDate(
    String name,
    dynamic value,
    tz.Location location,
    DateTime targetDate,
  ) {
    final hm = _parseHourMinute(name, value);
    if (hm == null) return null;
    final jamaatTime = tz.TZDateTime(
      location,
      targetDate.year,
      targetDate.month,
      targetDate.day,
      hm.hour,
      hm.minute,
    );
    final notifyTime = jamaatTime.subtract(reminderOffset);
    return _ParsedJamaatReminder(notifyTime: notifyTime);
  }

  static _HourMinute? _parseHourMinute(String name, dynamic value) {
    if (value is! String || value.isEmpty || value == '-') return null;
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
      return _HourMinute(hour, minute);
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

class _HourMinute {
  const _HourMinute(this.hour, this.minute);
  final int hour;
  final int minute;
}
