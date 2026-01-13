import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';
import '../services/settings_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final SettingsService _settingsService = SettingsService();
  bool _isInitialized = false;

  /// Initialize notification service
  Future<void> initialize([BuildContext? context]) async {
    if (_isInitialized) return;
    
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
        },
      );

      // Create notification channel for Android
      if (Platform.isAndroid) {
        await _createAllNotificationChannels();
      }

      // Request notification permissions for Android 13+ and iOS
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();
        if (androidImplementation != null) {
          await androidImplementation.requestNotificationsPermission();
        }
      }

      _isInitialized = true;
    } catch (e) {
      // Don't set _isInitialized to true if initialization failed
    }
  }

  /// Get the appropriate channel ID for prayer notifications
  String _getPrayerChannelId(int soundMode) {
    switch (soundMode) {
      case 0:
        return 'prayer_channel_custom';
      case 1:
        return 'prayer_channel_system';
      case 2:
        return 'prayer_channel_silent';
      default:
        return 'prayer_channel_custom';
    }
  }

  /// Get the appropriate channel ID for jamaat notifications
  String _getJamaatChannelId(int soundMode) {
    switch (soundMode) {
      case 0:
        return 'jamaat_channel_custom';
      case 1:
        return 'jamaat_channel_system';
      case 2:
        return 'jamaat_channel_silent';
      default:
        return 'jamaat_channel_custom';
    }
  }



  /// Get notification configuration based on type and sound mode
  Map<String, dynamic> _getNotificationConfig({
    required String notificationType,
    required int soundMode,
  }) {
    final isPrayer = notificationType == 'prayer';
    final channelId = isPrayer 
        ? _getPrayerChannelId(soundMode) 
        : _getJamaatChannelId(soundMode);
    
    return {
      'channelId': channelId,
      'playSound': soundMode != 2,
      'enableVibration': soundMode != 2,
    };
  }

  /// Create all notification channels for Android
  Future<void> _createAllNotificationChannels() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        // Create prayer notification channels
        final prayerCustomChannel = AndroidNotificationChannel(
          'prayer_channel_custom',
          'Prayer Notifications (Custom Sound)',
          description: 'Prayer notifications with custom adhan sound',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('allahu_akbar'),
        );

        const prayerSystemChannel = AndroidNotificationChannel(
          'prayer_channel_system',
          'Prayer Notifications (System Sound)',
          description: 'Prayer notifications with system default sound',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: null,
        );

        const prayerSilentChannel = AndroidNotificationChannel(
          'prayer_channel_silent',
          'Prayer Notifications (Silent)',
          description: 'Prayer notifications without sound',
          importance: Importance.max,
          playSound: false,
          enableVibration: false,
          showBadge: true,
          sound: null,
        );

        // Create jamaat notification channels
        final jamaatCustomChannel = AndroidNotificationChannel(
          'jamaat_channel_custom',
          'Jamaat Notifications (Custom Sound)',
          description: 'Jamaat notifications with custom adhan sound',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('allahu_akbar'),
        );

        const jamaatSystemChannel = AndroidNotificationChannel(
          'jamaat_channel_system',
          'Jamaat Notifications (System Sound)',
          description: 'Jamaat notifications with system default sound',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: null,
        );

        const jamaatSilentChannel = AndroidNotificationChannel(
          'jamaat_channel_silent',
          'Jamaat Notifications (Silent)',
          description: 'Jamaat notifications without sound',
          importance: Importance.max,
          playSound: false,
          enableVibration: false,
          showBadge: true,
          sound: null,
        );

        // Create all channels
        await androidImplementation.createNotificationChannel(prayerCustomChannel);
        await androidImplementation.createNotificationChannel(prayerSystemChannel);
        await androidImplementation.createNotificationChannel(prayerSilentChannel);
        await androidImplementation.createNotificationChannel(jamaatCustomChannel);
        await androidImplementation.createNotificationChannel(jamaatSystemChannel);
        await androidImplementation.createNotificationChannel(jamaatSilentChannel);
      }
    } catch (e) {
      developer.log(
        'Error creating notification channels: $e',
        name: 'NotificationService',
        error: e,
      );
      rethrow;
    }
  }

  /// Schedule notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String notificationType = 'prayer', // 'prayer' or 'jamaat'
  }) async {
    try {
      // Check if service is initialized
      if (!_isInitialized) {
        return;
      }

      if (scheduledTime.isBefore(DateTime.now())) {
        return;
      }

      final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
        scheduledTime,
        tz.local,
      );

      // Get the appropriate sound mode based on notification type
      int soundMode;
      try {
        if (notificationType == 'jamaat') {
          soundMode = await _settingsService.getJamaatNotificationSoundMode();
        } else {
          soundMode = await _settingsService.getPrayerNotificationSoundMode();
        }
      } catch (e) {
        soundMode = 0; // Default to custom sound
      }

      // Get notification configuration
      final config = _getNotificationConfig(
        notificationType: notificationType,
        soundMode: soundMode,
      );

      // Schedule the notification
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            config['channelId'],
            notificationType == 'prayer' ? 'Prayer Notifications' : 'Jamaat Notifications',
            channelDescription: 'Notifications for ${notificationType == 'prayer' ? 'prayer' : 'jamaat'} times',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            enableVibration: config['enableVibration'],
            playSound: config['playSound'],
            icon: '@mipmap/launcher_icon',
            color: const Color(0xFF388E3C),
            sound: config['playSound'] && soundMode == 0 
                ? RawResourceAndroidNotificationSound('allahu_akbar')
                : null,
            vibrationPattern: config['enableVibration']
                ? Int64List.fromList([0, 5000])
                : null,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      developer.log(
        'Error scheduling notification: $e',
        name: 'NotificationService',
        error: e,
      );
      rethrow;
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
    } catch (e) {
      developer.log(
        'Error cancelling notifications: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Calculate prayer notification times without scheduling them
  /// Returns a map of prayer names to their notification times
  Map<String, DateTime?> calculatePrayerNotificationTimes(
    Map<String, DateTime?> prayerTimes,
  ) {
    try {
      final Map<String, DateTime?> notificationTimes = {};

      // Convert prayer times to Bangladesh timezone before calculation
      final Map<String, DateTime> localPrayerTimes = {};
      for (final entry in prayerTimes.entries) {
        if (entry.value != null) {
          // Convert to Bangladesh timezone
          final localTime = tz.TZDateTime.from(entry.value!, tz.getLocation('Asia/Dhaka'));
          localPrayerTimes[entry.key] = localTime;
        }
      }

      // Calculate notification times with correct logic using local prayer times:
      // Fajr notification = 20 minutes before Sunrise
      if (localPrayerTimes.containsKey('Fajr') && localPrayerTimes.containsKey('Sunrise')) {
        final sunriseTime = localPrayerTimes['Sunrise']!;
        final notifyTime = sunriseTime.subtract(const Duration(minutes: 20));
        notificationTimes['Fajr'] = notifyTime;
      }
      
      // Dhuhr notification = 20 minutes before Asr
      if (localPrayerTimes.containsKey('Dhuhr') && localPrayerTimes.containsKey('Asr')) {
        final asrTime = localPrayerTimes['Asr']!;
        final notifyTime = asrTime.subtract(const Duration(minutes: 20));
        notificationTimes['Dhuhr'] = notifyTime;
      }
      
      // Asr notification = 20 minutes before Maghrib
      if (localPrayerTimes.containsKey('Asr') && localPrayerTimes.containsKey('Maghrib')) {
        final maghribTime = localPrayerTimes['Maghrib']!;
        final notifyTime = maghribTime.subtract(const Duration(minutes: 20));
        notificationTimes['Asr'] = notifyTime;
      }
      
      // Maghrib notification = 20 minutes before Isha
      if (localPrayerTimes.containsKey('Maghrib') && localPrayerTimes.containsKey('Isha')) {
        final ishaTime = localPrayerTimes['Isha']!;
        final notifyTime = ishaTime.subtract(const Duration(minutes: 20));
        notificationTimes['Maghrib'] = notifyTime;
      }
      
      // Isha notification = 20 minutes before next day's Fajr
      if (localPrayerTimes.containsKey('Isha') && localPrayerTimes.containsKey('Fajr')) {
        final fajrTime = localPrayerTimes['Fajr']!;
        // Add 1 day to Fajr time for next day
        final nextDayFajr = fajrTime.add(const Duration(days: 1));
        final notifyTime = nextDayFajr.subtract(const Duration(minutes: 20));
        notificationTimes['Isha'] = notifyTime;
      }
      
      return notificationTimes;
    } catch (e) {
      return {};
    }
  }

  /// Calculate jamaat notification times without scheduling them
  /// Returns a map of prayer names to their jamaat notification times
  Map<String, DateTime?> calculateJamaatNotificationTimes(
    Map<String, dynamic>? jamaatTimes,
  ) {
    try {
      final Map<String, DateTime?> notificationTimes = {};

      if (jamaatTimes != null) {
        // Use Bangladesh timezone consistently
        final dhakaLocation = tz.getLocation('Asia/Dhaka');
        final nowInDhaka = tz.TZDateTime.now(dhakaLocation);

        for (final entry in jamaatTimes.entries) {
          final name = entry.key;
          final value = entry.value;

          if (value != null && value is String && value.isNotEmpty && value != '-') {
            try {
              final parts = value.split(':');
              if (parts.length != 2) {
                developer.log(
                  'Invalid jamaat time format for $name: "$value" (expected HH:mm)',
                  name: 'NotificationService',
                );
                continue;
              }

              final hour = int.tryParse(parts[0]);
              final minute = int.tryParse(parts[1]);

              // Validate parsed values
              if (hour == null || minute == null) {
                developer.log(
                  'Failed to parse time components for $name: "$value"',
                  name: 'NotificationService',
                );
                continue;
              }

              // Validate time ranges
              if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
                developer.log(
                  'Time out of range for $name: hour=$hour, minute=$minute',
                  name: 'NotificationService',
                );
                continue;
              }

              // Create jamaat time in Bangladesh timezone (same as scheduling)
              final jamaatTime = tz.TZDateTime(
                dhakaLocation,
                nowInDhaka.year,
                nowInDhaka.month,
                nowInDhaka.day,
                hour,
                minute,
              );
              final notifyTime = jamaatTime.subtract(
                const Duration(minutes: 10),
              );

              // Store the notification time (convert to regular DateTime for display)
              // This preserves the actual time in Dhaka timezone
              notificationTimes[name] = DateTime(
                notifyTime.year,
                notifyTime.month,
                notifyTime.day,
                notifyTime.hour,
                notifyTime.minute,
              );
            } catch (e) {
              developer.log(
                'Error calculating notification time for $name: "$value" - $e',
                name: 'NotificationService',
                error: e,
              );
            }
          }
        }
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

  /// Schedule prayer notifications
  Future<void> schedulePrayerNotifications(
    Map<String, DateTime?> prayerTimes,
  ) async {
    try {
      // Use Bangladesh timezone consistently for all comparisons
      final dhakaLocation = tz.getLocation('Asia/Dhaka');
      final nowInDhaka = tz.TZDateTime.now(dhakaLocation);

      // Convert prayer times to Bangladesh timezone before calculation
      final Map<String, tz.TZDateTime> localPrayerTimes = {};
      for (final entry in prayerTimes.entries) {
        if (entry.value != null) {
          // Convert to Bangladesh timezone
          final localTime = tz.TZDateTime.from(entry.value!, dhakaLocation);
          localPrayerTimes[entry.key] = localTime;
        }
      }

      // Schedule notifications with correct logic using local prayer times:
      // Fajr notification = 20 minutes before Sunrise
      if (localPrayerTimes.containsKey('Fajr') && localPrayerTimes.containsKey('Sunrise')) {
        final sunriseTime = localPrayerTimes['Sunrise']!;
        final notifyTime = sunriseTime.subtract(const Duration(minutes: 20));

        // Compare TZDateTime objects directly in the same timezone
        if (notifyTime.isAfter(nowInDhaka)) {
          await scheduleNotification(
            id: 'Fajr'.hashCode,
            title: 'Fajr Prayer',
            body: 'Fajr time remaining 20 minutes.',
            scheduledTime: notifyTime,
            notificationType: 'prayer',
          );
        }
      }

      // Dhuhr notification = 20 minutes before Asr
      if (localPrayerTimes.containsKey('Dhuhr') && localPrayerTimes.containsKey('Asr')) {
        final asrTime = localPrayerTimes['Asr']!;
        final notifyTime = asrTime.subtract(const Duration(minutes: 20));

        if (notifyTime.isAfter(nowInDhaka)) {
          await scheduleNotification(
            id: 'Dhuhr'.hashCode,
            title: 'Dhuhr Prayer',
            body: 'Dhuhr time remaining 20 minutes.',
            scheduledTime: notifyTime,
            notificationType: 'prayer',
          );
        }
      }

      // Asr notification = 20 minutes before Maghrib
      if (localPrayerTimes.containsKey('Asr') && localPrayerTimes.containsKey('Maghrib')) {
        final maghribTime = localPrayerTimes['Maghrib']!;
        final notifyTime = maghribTime.subtract(const Duration(minutes: 20));

        if (notifyTime.isAfter(nowInDhaka)) {
          await scheduleNotification(
            id: 'Asr'.hashCode,
            title: 'Asr Prayer',
            body: 'Asr time remaining 20 minutes.',
            scheduledTime: notifyTime,
            notificationType: 'prayer',
          );
        }
      }

      // Maghrib notification = 20 minutes before Isha
      if (localPrayerTimes.containsKey('Maghrib') && localPrayerTimes.containsKey('Isha')) {
        final ishaTime = localPrayerTimes['Isha']!;
        final notifyTime = ishaTime.subtract(const Duration(minutes: 20));

        if (notifyTime.isAfter(nowInDhaka)) {
          await scheduleNotification(
            id: 'Maghrib'.hashCode,
            title: 'Maghrib Prayer',
            body: 'Maghrib time remaining 20 minutes.',
            scheduledTime: notifyTime,
            notificationType: 'prayer',
          );
        }
      }

      // Isha notification = 20 minutes before next day's Fajr
      if (localPrayerTimes.containsKey('Isha') && localPrayerTimes.containsKey('Fajr')) {
        final fajrTime = localPrayerTimes['Fajr']!;
        // Add 1 day to Fajr time for next day
        final nextDayFajr = fajrTime.add(const Duration(days: 1));
        final notifyTime = nextDayFajr.subtract(const Duration(minutes: 20));

        if (notifyTime.isAfter(nowInDhaka)) {
          await scheduleNotification(
            id: 'Isha'.hashCode,
            title: 'Isha Prayer',
            body: 'Isha time remaining 20 minutes.',
            scheduledTime: notifyTime,
            notificationType: 'prayer',
          );
        }
      }
    } catch (e) {
      developer.log(
        'Error in schedulePrayerNotifications: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Schedule Jamaat notifications with separate sound settings
  Future<void> scheduleJamaatNotifications(
    Map<String, dynamic>? jamaatTimes,
  ) async {
    try {
      if (jamaatTimes != null) {
        // Use Bangladesh timezone for all time comparisons
        final dhakaLocation = tz.getLocation('Asia/Dhaka');
        final nowInDhaka = tz.TZDateTime.now(dhakaLocation);

        for (final entry in jamaatTimes.entries) {
          final name = entry.key;
          final value = entry.value;

          if (value != null &&
              value is String &&
              value.isNotEmpty &&
              value != '-') {
            try {
              final parts = value.split(':');
              if (parts.length != 2) {
                developer.log(
                  'Invalid jamaat time format for $name: "$value" (expected HH:mm)',
                  name: 'NotificationService',
                );
                continue;
              }

              final hour = int.tryParse(parts[0]);
              final minute = int.tryParse(parts[1]);

              // Validate parsed values
              if (hour == null || minute == null) {
                developer.log(
                  'Failed to parse time components for $name: "$value"',
                  name: 'NotificationService',
                );
                continue;
              }

              // Validate time ranges
              if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
                developer.log(
                  'Time out of range for $name: hour=$hour, minute=$minute',
                  name: 'NotificationService',
                );
                continue;
              }

              // Create jamaat time in Bangladesh timezone
              final jamaatTime = tz.TZDateTime(
                dhakaLocation,
                nowInDhaka.year,
                nowInDhaka.month,
                nowInDhaka.day,
                hour,
                minute,
              );
              final notifyTime = jamaatTime.subtract(
                const Duration(minutes: 10),
              );

              // Compare TZDateTime objects directly in the same timezone
              // This fixes the midnight comparison issue
              if (notifyTime.isAfter(nowInDhaka)) {
                // Capitalize the prayer name for display
                final displayName = name.isNotEmpty
                    ? name[0].toUpperCase() + name.substring(1)
                    : name;
                await scheduleNotification(
                  id: name.hashCode + 1000,
                  title: '$displayName Jamaat',
                  body: '$displayName Jamaat is in 10 minutes.',
                  scheduledTime: notifyTime,
                  notificationType: 'jamaat',
                );
              }
            } catch (e) {
              developer.log(
                'Error parsing jamaat time for $name: "$value" - $e',
                name: 'NotificationService',
                error: e,
              );
            }
          }
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

  /// Schedule all notifications (prayer and Jamaat)
  Future<void> scheduleAllNotifications(
    Map<String, DateTime?> prayerTimes,
    Map<String, dynamic>? jamaatTimes,
  ) async {
    try {
      await cancelAllNotifications();
      await schedulePrayerNotifications(prayerTimes);
      await scheduleJamaatNotifications(jamaatTimes);
    } catch (e) {
      developer.log(
        'Error in scheduleAllNotifications: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Get pending notifications for debugging
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      developer.log(
        'Error getting pending notifications: $e',
        name: 'NotificationService',
        error: e,
      );
      return [];
    }
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    try {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        return await androidImplementation.areNotificationsEnabled() ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get initialization status
  bool get isInitialized => _isInitialized;

  /// Reset notification service
  Future<void> reset() async {
    _isInitialized = false;
    await initialize(null);
  }

  /// Check if notification service is ready
  Future<bool> isReady() async {
    if (!_isInitialized) {
      return false;
    }

    return await areNotificationsEnabled();
  }

  /// Recreate notification channel with new settings
  Future<void> recreateNotificationChannel() async {
    try {
      // Recreate channels with new settings
      await _createAllNotificationChannels();
    } catch (e) {
      developer.log(
        'Error recreating notification channels: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Handle notification sound mode change - recreate channel and reschedule notifications
  Future<void> handleNotificationSoundModeChange() async {
    try {
      // First, recreate the notification channel with new settings
      await recreateNotificationChannel();

      // Cancel all existing notifications to ensure they use the new channel settings
      await cancelAllNotifications();
    } catch (e) {
      developer.log(
        'Error handling notification sound mode change: $e',
        name: 'NotificationService',
        error: e,
      );
      rethrow;
    }
  }
}
