import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:jamaat_time/services/settings_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  final SettingsService _settingsService = SettingsService();

  /// Call this at app startup to ensure notifications are ready before scheduling.
  Future<void> initialize(BuildContext? context) async {
    if (_isInitialized) return;
    
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      final DarwinInitializationSettings initializationSettingsIOS =
          const DarwinInitializationSettings();
      final InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      final bool? initialized = await flutterLocalNotificationsPlugin.initialize(
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
      'channelName': isPrayer ? 'Prayer Notifications' : 'Jamaat Notifications',
      'channelDescription': isPrayer 
          ? 'Notifications for prayer times' 
          : 'Notifications for jamaat times',
      'playSound': soundMode != 2,
      'enableVibration': soundMode != 2,
      'customSound': soundMode == 0 ? 'allahu_akbar' : null,
    };
  }

  /// Log notification scheduling details
  void _logNotificationScheduling({
    required String notificationType,
    required String title,
    required DateTime scheduledTime,
    required int soundMode,
  }) {
    developer.log(
      'Scheduling $notificationType notification: $title at ${scheduledTime.toString()} with ${_getSoundModeText(soundMode)}',
      name: 'NotificationService',
    );
  }

  /// Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    try {
      // Get user's sound mode preference
      final mode = await _settingsService.getNotificationSoundMode();
      final channelId = _getChannelId(mode);
      RawResourceAndroidNotificationSound? customSound;
      bool playSound = mode != 2;

      // Only use custom sound if mode is 0 (custom) and we're on Android
      if (mode == 0 && Platform.isAndroid) {
        try {
          customSound = RawResourceAndroidNotificationSound('allahu_akbar');
          developer.log(
            'Custom sound configured: allahu_akbar',
            name: 'NotificationService',
          );
        } catch (e) {
          developer.log(
            'Error configuring custom sound, using system default: $e',
            name: 'NotificationService',
            error: e,
          );
          customSound = null;
        }
      }

      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        'Prayer Times',
        description: 'Notifications for prayer and Jamaat times',
        importance: Importance.max,
        playSound: playSound,
        enableVibration: playSound,
        showBadge: true,
        sound: customSound,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(channel);
        developer.log(
          'Notification channel created successfully with sound mode: $mode, channel ID: $channelId',
          name: 'NotificationService',
        );
      }
    } catch (e) {
      developer.log(
        'Error creating notification channel: $e',
        name: 'NotificationService',
        error: e,
      );
      // Fallback: create channel without custom sound
      try {
        const AndroidNotificationChannel fallbackChannel =
            AndroidNotificationChannel(
              'prayer_channel_system',
              'Prayer Times',
              description: 'Notifications for prayer and Jamaat times',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              showBadge: true,
              sound: null, // Use system default
            );

        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();

        if (androidImplementation != null) {
          await androidImplementation.createNotificationChannel(
            fallbackChannel,
          );
          developer.log(
            'Notification channel created with fallback settings',
            name: 'NotificationService',
          );
        }
      } catch (fallbackError) {
        developer.log(
          'Error creating fallback notification channel: $fallbackError',
          name: 'NotificationService',
          error: fallbackError,
        );
        // Final fallback: create basic channel
        try {
          const AndroidNotificationChannel basicChannel =
              AndroidNotificationChannel(
                'prayer_channel_basic',
                'Prayer Times',
                description: 'Notifications for prayer and Jamaat times',
                importance: Importance.high,
                playSound: true,
                enableVibration: true,
                showBadge: true,
              );

          final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
              flutterLocalNotificationsPlugin
                  .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin
                  >();

          if (androidImplementation != null) {
            await androidImplementation.createNotificationChannel(basicChannel);
            developer.log(
              'Basic notification channel created as final fallback',
              name: 'NotificationService',
            );
          }
        } catch (basicError) {
          developer.log(
            'Failed to create even basic notification channel: $basicError',
            name: 'NotificationService',
            error: basicError,
          );
        }
      }
    }
  }

  /// Show a dialog to inform the user that notification permissions are needed.
  void _showPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notification Permission Required'),
        content: const Text(
          'To receive prayer and Jamaat time reminders, please enable notification permissions for this app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Open app settings to allow user to enable notifications
  void _openAppSettings() {
    // This will open the app's notification settings
    // Note: This is a simplified approach - in a real app you might want to use a package like app_settings
    developer.log(
      'User should manually open app settings to enable notifications',
      name: 'NotificationService',
    );
  }

  Future<AndroidNotificationDetails> _androidDetails({
    required String channelId,
    required String channelName,
    required String? channelDescription,
    Color? color,
    Int64List? vibrationPattern,
  }) async {
    // Determine sound mode based on channel ID
    int soundMode;
    bool playSound;
    RawResourceAndroidNotificationSound? customSound;
    
    if (channelId.contains('custom')) {
      soundMode = 0;
      playSound = true;
      if (Platform.isAndroid) {
        try {
          customSound = RawResourceAndroidNotificationSound('allahu_akbar');
        } catch (e) {
          developer.log(
            'Error configuring custom sound in _androidDetails: $e',
            name: 'NotificationService',
            error: e,
          );
          customSound = null;
        }
      }
    } else if (channelId.contains('system')) {
      soundMode = 1;
      playSound = true;
      customSound = null;
    } else {
      soundMode = 2;
      playSound = false;
      customSound = null;
    }

    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: playSound,
      playSound: playSound,
      icon: '@mipmap/launcher_icon',
      color: color,
      sound: customSound,
      vibrationPattern: playSound
          ? (vibrationPattern ?? Int64List.fromList([0, 5000]))
          : null,
    );
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

      // Log notification scheduling
      _logNotificationScheduling(
        notificationType: notificationType,
        title: title,
        scheduledTime: scheduledTime,
        soundMode: soundMode,
      );

      final androidDetails = await _androidDetails(
        channelId: config['channelId'],
        channelName: config['channelName'],
        channelDescription: config['channelDescription'],
        color: const Color(0xFF43A047),
        vibrationPattern: Int64List.fromList([0, 5000]),
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            // Use custom adhan sound
            sound: 'adhan.wav',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // Remove matchDateTimeComponents to prevent daily repetition
        // matchDateTimeComponents: DateTimeComponents.time,
      );
      developer.log(
        'Notification scheduled successfully: $title at ${scheduledDate.toString()}',
        name: 'NotificationService',
      );
    } catch (e) {
      developer.log(
        'Error scheduling notification: $e',
        name: 'NotificationService',
        error: e,
      );
      // Try to recreate notification channel if scheduling fails
      try {
        await recreateNotificationChannel();
        developer.log(
          'Attempted to recreate notification channel after scheduling error',
          name: 'NotificationService',
        );
      } catch (recreateError) {
        developer.log(
          'Failed to recreate notification channel: $recreateError',
          name: 'NotificationService',
          error: recreateError,
        );
      }
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      developer.log('All notifications cancelled', name: 'NotificationService');
    } catch (e) {
      developer.log(
        'Error cancelling notifications: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Schedule prayer notifications with separate sound settings
  /// Each prayer notification is triggered 20 minutes before the NEXT prayer
  Future<void> schedulePrayerNotifications(
    Map<String, DateTime?> prayerTimes,
  ) async {
    try {
      int scheduledCount = 0;
      final now = DateTime.now();

      // Define the 5 main prayers in order
      final mainPrayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
      
      // Create a map of prayer times for easier lookup
      final Map<String, DateTime> prayerTimeMap = {};
      for (final prayer in mainPrayers) {
        final time = prayerTimes[prayer];
        if (time != null) {
          // Use the actual date from the prayer time, not the current date
          prayerTimeMap[prayer] = DateTime(
            time.year,
            time.month,
            time.day,
            time.hour,
            time.minute,
          );
        }
      }
      
      // Schedule notifications for each prayer (triggered 20 minutes before next prayer)
      for (int i = 0; i < mainPrayers.length; i++) {
        final currentPrayer = mainPrayers[i];
        final nextPrayer = mainPrayers[(i + 1) % mainPrayers.length]; // Wrap around for Isha -> Fajr
        
        final currentPrayerTime = prayerTimeMap[currentPrayer];
        final nextPrayerTime = prayerTimeMap[nextPrayer];
        
        if (currentPrayerTime != null && nextPrayerTime != null) {
          // Calculate notification time (20 minutes before next prayer)
          final notifyTime = nextPrayerTime.subtract(const Duration(minutes: 20));
          
          // Only schedule if notification time is in the future
          if (notifyTime.isAfter(now)) {
            await scheduleNotification(
              id: currentPrayer.hashCode,
              title: '$currentPrayer Prayer',
              body: '$currentPrayer time remaining 20 minutes.',
              scheduledTime: notifyTime,
              notificationType: 'prayer',
            );
            scheduledCount++;
          }
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
        int scheduledCount = 0;
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
                  scheduledCount++;
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

  /// Check device notification and sound settings
  Future<Map<String, dynamic>> checkDeviceSettings() async {
    final Map<String, dynamic> settings = {
      'deviceModel': Platform.isAndroid ? 'Android Device' : 'iOS Device',
      'androidVersion': Platform.isAndroid ? 'Android' : 'iOS',
      'notificationsEnabled': false,
      'soundEnabled': true,
      'vibrationEnabled': true,
      'doNotDisturb': false,
      'batteryOptimization': false,
      'appNotifications': false,
    };

    try {
      // Check basic notification permissions
      settings['notificationsEnabled'] = await areNotificationsEnabled();

      // For Android, we can check more settings
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();

        if (androidImplementation != null) {
          // Check if notifications are enabled for the app
          settings['appNotifications'] =
              await androidImplementation.areNotificationsEnabled() ?? false;
        }
      }

      developer.log(
        'Device settings check completed: $settings',
        name: 'NotificationService',
      );
      return settings;
    } catch (e) {
      developer.log(
        'Error checking device settings: $e',
        name: 'NotificationService',
        error: e,
      );
      settings['error'] = e.toString();
      return settings;
    }
  }

  /// Show detailed device settings information
  void showDeviceSettingsInfo(BuildContext context) {
    checkDeviceSettings().then((settings) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Device Settings Check'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Device: ${settings['deviceModel']}'),
                Text(
                  'Notifications Enabled: ${settings['notificationsEnabled']}',
                ),
                Text('App Notifications: ${settings['appNotifications']}'),
                const SizedBox(height: 16),
                const Text(
                  'If notifications are not working:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text('1. Check device notification settings'),
                const Text('2. Ensure Do Not Disturb is OFF'),
                const Text('3. Check app notification permissions'),
                const Text('4. Verify device volume is ON'),
                const Text('5. Check battery optimization settings'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    });
  }

  /// Check if notification permissions are granted
  Future<bool> areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();
        if (androidImplementation != null) {
          return await androidImplementation.areNotificationsEnabled() ?? false;
        }
      }
      return false;
    } catch (e) {
      developer.log(
        'Error checking notification permissions: $e',
        name: 'NotificationService',
        error: e,
      );
      return false;
    }
  }

  /// Check if notification service is properly initialized
  bool get isInitialized => _isInitialized;

  /// Force reinitialize the notification service
  Future<void> reinitialize(BuildContext? context) async {
    _isInitialized = false;
    await initialize(context);
  }

  /// Test notification for debugging
  Future<void> testNotification() async {
    try {
      if (!_isInitialized) {
        developer.log(
          'Cannot test notification - service not initialized',
          name: 'NotificationService',
        );
        throw Exception('Notification service not initialized');
      }

      developer.log(
        'Testing notification...',
        name: 'NotificationService',
      );

      // Get current prayer sound mode for testing
      final prayerMode = await _settingsService.getPrayerNotificationSoundMode();
      final jamaatMode = await _settingsService.getJamaatNotificationSoundMode();
      developer.log(
        'Current prayer notification sound mode: $prayerMode, jamaat mode: $jamaatMode',
        name: 'NotificationService',
      );

      final androidDetails = await _androidDetails(
        channelId: _getPrayerChannelId(prayerMode),
        channelName: 'Prayer Notifications',
        channelDescription: 'Test notification for prayer times',
        color: const Color(0xFF43A047),
        vibrationPattern: Int64List.fromList([0, 5000]),
      );

      await flutterLocalNotificationsPlugin.show(
        999,
        'Test Notification - Jamaat Time',
        'This is a test notification to verify sound settings. Prayer Mode: ${_getSoundModeText(prayerMode)}, Jamaat Mode: ${_getSoundModeText(jamaatMode)}',
        NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );

      developer.log(
        'Test notification sent successfully with prayer sound mode: $prayerMode, jamaat sound mode: $jamaatMode',
        name: 'NotificationService',
      );
    } catch (e) {
      developer.log(
        'Error sending test notification: $e',
        name: 'NotificationService',
        error: e,
      );
      rethrow;
    }
  }



  /// Get system information for debugging
  Future<String> getSystemInfo() async {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final version = androidInfo.version;
      final sdkInt = androidInfo.version.sdkInt;
      final manufacturer = androidInfo.manufacturer;
      final model = androidInfo.model;

      return 'Android $version (SDK $sdkInt) - $manufacturer $model';
    } catch (e) {
      return 'Error getting system info: $e';
    }
  }

  /// Recreate notification channel with custom sound
  Future<void> recreateNotificationChannel() async {
    try {
      developer.log(
        'Recreating notification channels for all sound modes...',
        name: 'NotificationService',
      );

      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidImplementation != null) {
        // Delete all existing channels to ensure clean recreation
        await androidImplementation.deleteNotificationChannel('prayer_channel_custom');
        await androidImplementation.deleteNotificationChannel('prayer_channel_system');
        await androidImplementation.deleteNotificationChannel('prayer_channel_silent');
        await androidImplementation.deleteNotificationChannel('jamaat_channel_custom');
        await androidImplementation.deleteNotificationChannel('jamaat_channel_system');
        await androidImplementation.deleteNotificationChannel('jamaat_channel_silent');
        await androidImplementation.deleteNotificationChannel('prayer_channel'); // Legacy channel

        developer.log(
          'Deleted existing notification channels',
          name: 'NotificationService',
        );

        // Create channels for all sound modes
        await _createAllNotificationChannels();
        
        developer.log(
          'All notification channels recreated successfully',
          name: 'NotificationService',
        );
      }
    } catch (e) {
      developer.log(
        'Error recreating notification channels: $e',
        name: 'NotificationService',
        error: e,
      );
    }
  }

  /// Create all notification channels for different sound modes
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
