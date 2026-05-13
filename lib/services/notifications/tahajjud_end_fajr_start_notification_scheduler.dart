import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/app_text.dart';
import '../settings_service.dart';
import 'notification_ids.dart';
import 'notification_localization.dart';
import 'notification_schedule_gateway.dart';

class TahajjudEndFajrStartNotificationScheduler {
  TahajjudEndFajrStartNotificationScheduler({
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

  Future<void> schedule({
    required Map<String, DateTime?> todayPrayerTimes,
    Map<String, DateTime?>? tomorrowPrayerTimes,
  }) async {
    try {
      final enabled = await _settingsService.getFajrVoiceNotificationEnabled();

      if (!enabled) {
        await _scheduleGateway.cancel(NotificationIds.fajrVoice);
        await _scheduleGateway.cancel(NotificationIds.fajrVoiceTomorrow);
        developer.log(
          'JT_NOTIFY fajr_voice skipped reason=disabled',
          name: 'NotificationService',
        );
        return;
      }

      final location = _locationResolver();
      final now = tz.TZDateTime.now(location);
      final locale = await _localeResolver();
      final strings = AppText.of(locale);
      final prayerLabel = localizedPrayerName(locale, 'Fajr');

      final todayFajr = todayPrayerTimes['Fajr'];
      final tomorrowFajr = tomorrowPrayerTimes?['Fajr'];

      final todayFajrLocal = todayFajr == null
          ? null
          : tz.TZDateTime.from(todayFajr, location);
      final tomorrowFajrLocal = tomorrowFajr == null
          ? null
          : tz.TZDateTime.from(tomorrowFajr, location);

      final todayIsFuture =
          todayFajrLocal != null && todayFajrLocal.isAfter(now);

      // Primary slot: next future Fajr (today if still ahead, else tomorrow).
      if (todayIsFuture) {
        await _scheduleGateway.scheduleFajrVoice(
          id: NotificationIds.fajrVoice,
          title: strings.notification_prayerTitle(prayerLabel),
          body: strings.notification_fajrStartBody(prayerLabel),
          scheduledTime: todayFajrLocal,
        );
      } else if (tomorrowFajrLocal != null && tomorrowFajrLocal.isAfter(now)) {
        await _scheduleGateway.scheduleFajrVoice(
          id: NotificationIds.fajrVoice,
          title: strings.notification_prayerTitle(prayerLabel),
          body: strings.notification_fajrStartBody(prayerLabel),
          scheduledTime: tomorrowFajrLocal,
        );
      } else {
        developer.log(
          'JT_NOTIFY fajr_voice skipped id=${NotificationIds.fajrVoice} reason=no_future_fajr',
          name: 'NotificationService',
        );
      }

      // Secondary slot: only meaningful when today's Fajr is still ahead,
      // i.e. we have a distinct tomorrow-Fajr value to arm.
      if (todayIsFuture &&
          tomorrowFajrLocal != null &&
          tomorrowFajrLocal.isAfter(now)) {
        await _scheduleGateway.scheduleFajrVoice(
          id: NotificationIds.fajrVoiceTomorrow,
          title: strings.notification_prayerTitle(prayerLabel),
          body: strings.notification_fajrStartBody(prayerLabel),
          scheduledTime: tomorrowFajrLocal,
        );
      } else {
        await _scheduleGateway.cancel(NotificationIds.fajrVoiceTomorrow);
      }
    } catch (e) {
      developer.log(
        'JT_NOTIFY error fajr_voice $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  static tz.TZDateTime nextTahajjudEndFajrStartNotificationTime({
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
