// ignore_for_file: avoid_print

import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/timezone_bootstrap.dart';
import '../settings_service.dart';
import 'notification_channel_service.dart';
import 'notification_permission_service.dart';

class NotificationScheduleGateway {
  NotificationScheduleGateway({
    required FlutterLocalNotificationsPlugin plugin,
    required SettingsService settingsService,
    required NotificationChannelService channelService,
    required NotificationPermissionService permissionService,
    required bool Function() isInitialized,
  }) : _plugin = plugin,
       _settingsService = settingsService,
       _channelService = channelService,
       _permissionService = permissionService,
       _isInitialized = isInitialized;

  final FlutterLocalNotificationsPlugin _plugin;
  final SettingsService _settingsService;
  final NotificationChannelService _channelService;
  final NotificationPermissionService _permissionService;
  final bool Function() _isInitialized;

  Future<void> scheduleStandard({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String notificationType,
  }) async {
    try {
      ensureTimeZonesInitialized();
      if (!_isInitialized()) {
        print('JT_NOTIFY skipped id=$id type=$notificationType reason=not_initialized');
        developer.log(
          'JT_NOTIFY skipped id=$id reason=not_initialized',
          name: 'NotificationService',
        );
        return;
      }

      if (scheduledTime.isBefore(DateTime.now())) {
        print('JT_NOTIFY skipped id=$id type=$notificationType reason=in_past at=$scheduledTime now=${DateTime.now()}');
        developer.log(
          'JT_NOTIFY skipped id=$id reason=in_past',
          name: 'NotificationService',
        );
        return;
      }

      final scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);

      int soundMode;
      try {
        if (notificationType == 'jamaat') {
          soundMode = await _settingsService.getJamaatNotificationSoundMode();
        } else {
          soundMode = await _settingsService.getPrayerNotificationSoundMode();
        }
      } catch (e) {
        print('JT_NOTIFY sound_mode_read_failed id=$id type=$notificationType $e — fallback=3');
        soundMode = 3;
      }

      final config = NotificationChannelService.notificationConfig(
        notificationType: notificationType,
        soundMode: soundMode,
      );
      final customSoundResource =
          NotificationChannelService.customSoundResource(
            notificationType: notificationType,
            soundMode: soundMode,
          );

      try {
        await _channelService.ensureChannelById(config.channelId);
      } catch (e) {
        print(
          'JT_NOTIFY channel_ensure_failed id=$id type=$notificationType '
          'channel=${config.channelId} $e',
        );
        rethrow;
      }

      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          NotificationDetails(
            android: AndroidNotificationDetails(
              config.channelId,
              notificationType == 'prayer'
                  ? 'Prayer Notifications'
                  : 'Jamaat Notifications',
              channelDescription:
                  'Notifications for ${notificationType == 'prayer' ? 'prayer' : 'jamaat'} times',
              importance: Importance.max,
              priority: Priority.high,
              showWhen: true,
              enableVibration: config.enableVibration,
              playSound: config.playSound,
              icon: '@mipmap/launcher_icon',
              color: const Color(0xFF388E3C),
              sound: customSoundResource != null
                  ? RawResourceAndroidNotificationSound(customSoundResource)
                  : null,
              vibrationPattern: config.enableVibration
                  ? Int64List.fromList([0, 5000])
                  : null,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: _permissionService.androidScheduleMode,
        );
      } catch (e) {
        print(
          'JT_NOTIFY zoned_schedule_failed id=$id type=$notificationType '
          'channel=${config.channelId} sound=$customSoundResource at=$scheduledDate $e',
        );
        rethrow;
      }
      print(
        'JT_NOTIFY ${notificationType == 'jamaat' ? 'jamaat_reminder' : 'prayer_end'} '
        'scheduled id=$id type=$notificationType '
        'channel=${config.channelId} at=${scheduledDate.toIso8601String()} '
        'mode=${_permissionService.exactAlarmsAvailable ? "exact" : "inexact"}',
      );
      developer.log(
        'JT_NOTIFY ${notificationType == 'jamaat' ? 'jamaat_reminder' : 'prayer_end'} scheduled id=$id type=$notificationType at=${scheduledDate.toIso8601String()} mode=${_permissionService.exactAlarmsAvailable ? "exact" : "inexact"}',
        name: 'NotificationService',
      );
    } catch (e) {
      print('JT_NOTIFY error id=$id type=$notificationType $e');
      developer.log(
        'JT_NOTIFY error id=$id $e',
        name: 'NotificationService',
        error: e,
      );
      rethrow;
    }
  }

  Future<void> scheduleFajrVoice({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
  }) async {
    try {
      await _channelService.ensureChannelById('fajr_voice_channel_v1');
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'fajr_voice_channel_v1',
            'Tahajjud end and Fajr start voice notification',
            channelDescription:
                'Plays voice reminder at Fajr prayer start time',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
            icon: '@mipmap/launcher_icon',
            color: const Color(0xFF388E3C),
            sound: RawResourceAndroidNotificationSound('fajr_prayer_voice'),
            vibrationPattern: Int64List.fromList([0, 5000]),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: _permissionService.androidScheduleMode,
      );
      developer.log(
        'JT_NOTIFY fajr_voice scheduled id=$id at=${scheduledTime.toIso8601String()} mode=${_permissionService.exactAlarmsAvailable ? "exact" : "inexact"}',
        name: 'NotificationService',
      );
    } catch (e) {
      developer.log(
        'JT_NOTIFY error id=$id $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  Future<List<PendingNotificationRequest>> pendingNotificationRequests() {
    return _plugin.pendingNotificationRequests();
  }
}
