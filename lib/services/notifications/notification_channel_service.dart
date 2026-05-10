import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../settings_service.dart';

class NotificationChannelConfig {
  const NotificationChannelConfig({
    required this.channelId,
    required this.playSound,
    required this.enableVibration,
  });

  final String channelId;
  final bool playSound;
  final bool enableVibration;
}

class NotificationChannelService {
  NotificationChannelService({
    required FlutterLocalNotificationsPlugin plugin,
    required SettingsService settingsService,
  }) : _plugin = plugin,
       _settingsService = settingsService;

  final FlutterLocalNotificationsPlugin _plugin;
  final SettingsService _settingsService;
  final Set<String> _createdChannelIds = <String>{};

  AndroidFlutterLocalNotificationsPlugin? _androidPlugin() => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  static String prayerChannelId(int soundMode) {
    switch (soundMode) {
      case 0:
        return 'prayer_channel_custom';
      case 1:
        return 'prayer_channel_system';
      case 2:
        return 'prayer_channel_silent';
      case 3:
        return 'prayer_channel_custom_2';
      case 4:
        return 'prayer_channel_custom_3';
      default:
        return 'prayer_channel_custom';
    }
  }

  static String jamaatChannelId(int soundMode) {
    switch (soundMode) {
      case 0:
        return 'jamaat_channel_custom';
      case 1:
        return 'jamaat_channel_system';
      case 2:
        return 'jamaat_channel_silent';
      case 3:
        return 'jamaat_channel_custom_2';
      case 4:
        return 'jamaat_channel_custom_3';
      default:
        return 'jamaat_channel_custom';
    }
  }

  static String? customSoundResource({
    required String notificationType,
    required int soundMode,
  }) {
    final isPrayer = notificationType == 'prayer';

    switch (soundMode) {
      case 0:
        return isPrayer ? 'prayer_allahu_akbar' : 'jamaat_allahu_akbar';
      case 3:
        return isPrayer ? 'prayer_custom_2' : 'jamaat_custom_2';
      case 4:
        return isPrayer ? 'prayer_custom_3' : 'jamaat_custom_3';
      default:
        return null;
    }
  }

  static NotificationChannelConfig notificationConfig({
    required String notificationType,
    required int soundMode,
  }) {
    final isPrayer = notificationType == 'prayer';
    final channelId = isPrayer
        ? prayerChannelId(soundMode)
        : jamaatChannelId(soundMode);

    return NotificationChannelConfig(
      channelId: channelId,
      playSound: soundMode != 2,
      enableVibration: soundMode != 2,
    );
  }

  static AndroidNotificationChannel? buildChannelById(String id) {
    switch (id) {
      case 'prayer_channel_custom':
        return AndroidNotificationChannel(
          'prayer_channel_custom',
          'Prayer Notifications (Custom Sound)',
          description: 'Prayer notifications with custom adhan sound',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('prayer_allahu_akbar'),
        );
      case 'prayer_channel_custom_2':
        return AndroidNotificationChannel(
          'prayer_channel_custom_2',
          'Prayer Notifications (Custom Sound 2)',
          description: 'Prayer notifications with custom adhan sound 2',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('prayer_custom_2'),
        );
      case 'prayer_channel_custom_3':
        return AndroidNotificationChannel(
          'prayer_channel_custom_3',
          'Prayer Notifications (Custom Sound 3)',
          description: 'Prayer notifications with custom adhan sound 3',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('prayer_custom_3'),
        );
      case 'prayer_channel_system':
        return const AndroidNotificationChannel(
          'prayer_channel_system',
          'Prayer Notifications (System Sound)',
          description: 'Prayer notifications with system default sound',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: null,
        );
      case 'prayer_channel_silent':
        return const AndroidNotificationChannel(
          'prayer_channel_silent',
          'Prayer Notifications (Silent)',
          description: 'Prayer notifications without sound',
          importance: Importance.max,
          playSound: false,
          enableVibration: false,
          showBadge: true,
          sound: null,
        );
      case 'jamaat_channel_custom':
        return AndroidNotificationChannel(
          'jamaat_channel_custom',
          'Jamaat Notifications (Custom Sound)',
          description: 'Jamaat notifications with custom adhan sound',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('jamaat_allahu_akbar'),
        );
      case 'jamaat_channel_custom_2':
        return AndroidNotificationChannel(
          'jamaat_channel_custom_2',
          'Jamaat Notifications (Custom Sound 2)',
          description: 'Jamaat notifications with custom adhan sound 2',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('jamaat_custom_2'),
        );
      case 'jamaat_channel_custom_3':
        return AndroidNotificationChannel(
          'jamaat_channel_custom_3',
          'Jamaat Notifications (Custom Sound 3)',
          description: 'Jamaat notifications with custom adhan sound 3',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('jamaat_custom_3'),
        );
      case 'jamaat_channel_system':
        return const AndroidNotificationChannel(
          'jamaat_channel_system',
          'Jamaat Notifications (System Sound)',
          description: 'Jamaat notifications with system default sound',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: null,
        );
      case 'jamaat_channel_silent':
        return const AndroidNotificationChannel(
          'jamaat_channel_silent',
          'Jamaat Notifications (Silent)',
          description: 'Jamaat notifications without sound',
          importance: Importance.max,
          playSound: false,
          enableVibration: false,
          showBadge: true,
          sound: null,
        );
      case 'fajr_voice_channel_v1':
        return AndroidNotificationChannel(
          'fajr_voice_channel_v1',
          'Fajr Voice Notification',
          description: 'Plays voice reminder at Fajr prayer start time',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
          sound: RawResourceAndroidNotificationSound('fajr_prayer_voice'),
        );
      default:
        return null;
    }
  }

  static const List<String> allChannelIds = <String>[
    'prayer_channel_custom',
    'prayer_channel_custom_2',
    'prayer_channel_custom_3',
    'prayer_channel_system',
    'prayer_channel_silent',
    'jamaat_channel_custom',
    'jamaat_channel_custom_2',
    'jamaat_channel_custom_3',
    'jamaat_channel_system',
    'jamaat_channel_silent',
    'fajr_voice_channel_v1',
  ];

  Future<void> ensureChannelById(String id) async {
    if (_createdChannelIds.contains(id)) return;
    if (!Platform.isAndroid) return;
    final channel = buildChannelById(id);
    if (channel == null) {
      developer.log(
        'JT_NOTIFY ensureChannel unknown id=$id',
        name: 'NotificationService',
      );
      return;
    }
    final androidImpl = _androidPlugin();
    if (androidImpl == null) return;
    await androidImpl.createNotificationChannel(channel);
    _createdChannelIds.add(id);
  }

  Future<void> createActiveChannelsForBoot() async {
    if (!Platform.isAndroid) return;
    int prayerSoundMode;
    int jamaatSoundMode;
    try {
      prayerSoundMode = await _settingsService.getPrayerNotificationSoundMode();
    } catch (_) {
      prayerSoundMode = 3;
    }
    try {
      jamaatSoundMode = await _settingsService.getJamaatNotificationSoundMode();
    } catch (_) {
      jamaatSoundMode = 3;
    }
    await ensureChannelById(prayerChannelId(prayerSoundMode));
    await ensureChannelById(jamaatChannelId(jamaatSoundMode));
    await ensureChannelById('fajr_voice_channel_v1');
  }

  Future<void> recreateAllChannels() async {
    try {
      if (!Platform.isAndroid) return;
      for (final id in allChannelIds) {
        await ensureChannelById(id);
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
}
