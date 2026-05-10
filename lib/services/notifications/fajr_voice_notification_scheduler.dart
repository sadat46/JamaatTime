import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/app_text.dart';
import '../settings_service.dart';
import 'notification_ids.dart';
import 'notification_localization.dart';
import 'notification_schedule_gateway.dart';

class FajrVoiceNotificationScheduler {
  FajrVoiceNotificationScheduler({
    required NotificationScheduleGateway scheduleGateway,
    required SettingsService settingsService,
    required Future<Locale> Function() localeResolver,
    required tz.Location Function() locationResolver,
  }) : _scheduleGateway = scheduleGateway,
       _settingsService = settingsService,
       _localeResolver = localeResolver,
       _locationResolver = locationResolver;

  final NotificationScheduleGateway _scheduleGateway;
  final SettingsService _settingsService;
  final Future<Locale> Function() _localeResolver;
  final tz.Location Function() _locationResolver;

  Future<void> schedule(Map<String, DateTime?> prayerTimes) async {
    try {
      final enabled = await _settingsService.getFajrVoiceNotificationEnabled();

      if (!enabled) {
        await _scheduleGateway.cancel(NotificationIds.fajrVoice);
        developer.log(
          'JT_NOTIFY fajr_voice skipped id=${NotificationIds.fajrVoice} reason=disabled',
          name: 'NotificationService',
        );
        return;
      }

      final fajrTime = prayerTimes['Fajr'];
      if (fajrTime == null) {
        developer.log(
          'JT_NOTIFY fajr_voice skipped id=${NotificationIds.fajrVoice} reason=no_fajr_time',
          name: 'NotificationService',
        );
        return;
      }

      final location = _locationResolver();
      final now = tz.TZDateTime.now(location);
      final fajrLocal = nextFajrVoiceNotificationTime(
        fajrTime: fajrTime,
        now: now,
        location: location,
      );

      final locale = await _localeResolver();
      final strings = AppText.of(locale);
      final prayerLabel = localizedPrayerName(locale, 'Fajr');

      await _scheduleGateway.scheduleFajrVoice(
        id: NotificationIds.fajrVoice,
        title: strings.notification_prayerTitle(prayerLabel),
        body: strings.notification_fajrStartBody(prayerLabel),
        scheduledTime: fajrLocal,
      );
    } catch (e) {
      developer.log(
        'JT_NOTIFY error id=${NotificationIds.fajrVoice} $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  static tz.TZDateTime nextFajrVoiceNotificationTime({
    required DateTime fajrTime,
    required tz.TZDateTime now,
    required tz.Location location,
  }) {
    final fajrLocal = tz.TZDateTime.from(fajrTime, location);
    return fajrLocal.isAfter(now)
        ? fajrLocal
        : fajrLocal.add(const Duration(days: 1));
  }
}
