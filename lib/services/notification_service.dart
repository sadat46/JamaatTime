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

  /// Get the appropriate channel ID based on sound mode
  String _getChannelId(int soundMode) {
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

  /// Get notification sound mode text for display
  String _getSoundModeText(int mode) {
    switch (mode) {
      case 0:
        return 'Custom Sound';
      case 1:
        return 'System Sound';
      case 2:
        return 'No Sound';
      default:
        return 'Custom Sound';
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

  /// Log notification scheduling for debugging
  void _logNotificationScheduling({
    required String title,
    required DateTime scheduledTime,
    required String notificationType,
    required int soundMode,
  }) {
    developer.log(
      'Scheduling $notificationType notification: $title at ${scheduledTime.toString()} with sound mode: $soundMode',
      name: 'NotificationService',
    );
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

        developer.log(
          'All notification channels created successfully',
          name: 'NotificationService',
        );
      }
    } catch (e) {
      developer.log(
        'Error creating all notification channels: $e',
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
        developer.log(
          'Notification service not initialized, skipping notification: $title',
          name: 'NotificationService',
        );
        return;
      }

      if (scheduledTime.isBefore(DateTime.now())) {
        developer.log(
          'Skipping past notification: $title at ${scheduledTime.toString()}',
          name: 'NotificationService',
        );
        return;
      }

      // Additional check for reasonable notification times
      if (scheduledTime.hour >= 22 || scheduledTime.hour <= 4) {
        developer.log(
          'WARNING: Scheduling notification at unusual time: $title at ${scheduledTime.toString()}',
          name: 'NotificationService',
        );
      }

      final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
        scheduledTime,
        tz.local,
      );
      developer.log(
        'Scheduling notification: $title at ${scheduledDate.toString()}',
        name: 'NotificationService',
      );
      developer.log(
        'Notification details - ID: $id, Title: $title, Time: ${scheduledDate.hour}:${scheduledDate.minute.toString().padLeft(2, '0')}',
        name: 'NotificationService',
      );

      // Get the appropriate sound mode based on notification type
      int soundMode;
      if (notificationType == 'jamaat') {
        soundMode = await _settingsService.getJamaatNotificationSoundMode();
      } else {
        soundMode = await _settingsService.getPrayerNotificationSoundMode();
      }

      // Get notification configuration
      final config = _getNotificationConfig(
        notificationType: notificationType,
        soundMode: soundMode,
      );

      // Log the scheduling
      _logNotificationScheduling(
        title: title,
        scheduledTime: scheduledDate,
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

      developer.log(
        'Notification scheduled successfully: $title',
        name: 'NotificationService',
      );
    } catch (e) {
      developer.log(
        'Error scheduling notification: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      developer.log(
        'All notifications cancelled',
        name: 'NotificationService',
      );
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
      final now = DateTime.now();
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
      final now = DateTime.now();
      final Map<String, DateTime?> notificationTimes = {};

      if (jamaatTimes != null) {
        for (final entry in jamaatTimes.entries) {
          final name = entry.key;
          final value = entry.value;
          if (value != null && value is String && value.isNotEmpty && value != '-') {
            try {
              final parts = value.split(':');
              if (parts.length == 2) {
                final jamaatTime = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  int.parse(parts[0]),
                  int.parse(parts[1]),
                );
                final notifyTime = jamaatTime.subtract(
                  const Duration(minutes: 10),
                );

                // Store the notification time (regardless of whether it's in the future)
                notificationTimes[name] = notifyTime;
              }
            } catch (e) {
              // Handle parsing error silently
            }
          }
        }
      }
      
      return notificationTimes;
    } catch (e) {
      return {};
    }
  }

  /// Schedule prayer notifications
  Future<void> schedulePrayerNotifications(
    Map<String, DateTime?> prayerTimes,
  ) async {
    try {
      final now = DateTime.now();
      
      // Convert prayer times to Bangladesh timezone before calculation
      final Map<String, DateTime> localPrayerTimes = {};
      for (final entry in prayerTimes.entries) {
        if (entry.value != null) {
          // Convert to Bangladesh timezone
          final localTime = tz.TZDateTime.from(entry.value!, tz.getLocation('Asia/Dhaka'));
          localPrayerTimes[entry.key] = localTime;
        }
      }
      
      // Schedule notifications with correct logic using local prayer times:
      // Fajr notification = 20 minutes before Sunrise
      if (localPrayerTimes.containsKey('Fajr') && localPrayerTimes.containsKey('Sunrise')) {
        final sunriseTime = localPrayerTimes['Sunrise']!;
        final notifyTime = sunriseTime.subtract(const Duration(minutes: 20));
        
        if (notifyTime.isAfter(now)) {
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
        
        if (notifyTime.isAfter(now)) {
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
        
        if (notifyTime.isAfter(now)) {
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
        
        if (notifyTime.isAfter(now)) {
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
        
        if (notifyTime.isAfter(now)) {
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
      // Handle error silently
    }
  }

  /// Schedule Jamaat notifications with separate sound settings
  Future<void> scheduleJamaatNotifications(
    Map<String, dynamic>? jamaatTimes,
  ) async {
    try {
      if (jamaatTimes != null) {
        // int scheduledCount = 0; // Count for debugging if needed
        final now = DateTime.now();

        for (final entry in jamaatTimes.entries) {
          final name = entry.key;
          final value = entry.value;
          if (value != null &&
              value is String &&
              value.isNotEmpty &&
              value != '-') {
            try {
              final parts = value.split(':');
              if (parts.length == 2) {
                final jamaatTime = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  int.parse(parts[0]),
                  int.parse(parts[1]),
                );
                final notifyTime = jamaatTime.subtract(
                  const Duration(minutes: 10),
                );

                // Only schedule if notification time is in the future
                if (notifyTime.isAfter(now)) {
                  await scheduleNotification(
                    id: name.hashCode + 1000,
                    title: '$name Jamaat',
                    body: '$name Jamaat is in 10 minutes.',
                    scheduledTime: notifyTime,
                    notificationType: 'jamaat',
                  );
                  // scheduledCount++; // Count for debugging if needed
                }
              }
            } catch (e) {
              // Handle parsing error silently
            }
          }
        }
      }
    } catch (e) {
      // Handle error silently
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
      // Handle error silently
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
      final prayerMode = await _settingsService.getPrayerNotificationSoundMode();
      final jamaatMode = await _settingsService.getJamaatNotificationSoundMode();

      // Recreate channels with new settings
      await _createAllNotificationChannels();

      developer.log(
        'Notification channels recreated with new settings. Prayer Mode: $prayerMode, Jamaat Mode: $jamaatMode',
        name: 'NotificationService',
      );
    } catch (e) {
      developer.log(
        'Error recreating notification channels: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Show test notification
  Future<void> showTestNotification() async {
    try {
      final prayerMode = await _settingsService.getPrayerNotificationSoundMode();
      final jamaatMode = await _settingsService.getJamaatNotificationSoundMode();

      await flutterLocalNotificationsPlugin.show(
        999,
        'Test Notification',
        'This is a test notification to verify sound settings. Prayer Mode: ${_getSoundModeText(prayerMode)}, Jamaat Mode: ${_getSoundModeText(jamaatMode)}',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _getPrayerChannelId(prayerMode),
            'Test Notifications',
            channelDescription: 'Test notifications for debugging',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
            icon: '@mipmap/launcher_icon',
            color: const Color(0xFF388E3C),
            sound: RawResourceAndroidNotificationSound('allahu_akbar'),
            vibrationPattern: Int64List.fromList([0, 5000]),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );

      developer.log(
        'Test notification shown successfully',
        name: 'NotificationService',
      );
    } catch (e) {
      developer.log(
        'Error showing test notification: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Handle notification sound mode change - recreate channel and reschedule notifications
  Future<void> handleNotificationSoundModeChange() async {
    try {
      developer.log(
        'Handling notification sound mode change...',
        name: 'NotificationService',
      );

      // First, recreate the notification channel with new settings
      await recreateNotificationChannel();

      // Cancel all existing notifications to ensure they use the new channel settings
      await cancelAllNotifications();
      developer.log(
        'Cancelled all existing notifications',
        name: 'NotificationService',
      );

      // Note: We don't reschedule notifications here because we don't have access to prayer times
      // The home screen will handle rescheduling when it detects the change
      developer.log(
        'Notification sound mode change handled successfully',
        name: 'NotificationService',
      );
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
