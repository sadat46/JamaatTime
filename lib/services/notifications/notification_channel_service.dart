import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../settings_service.dart';
import 'channels/fajr_voice_channel.dart';
import 'channels/jamaat_channels.dart';
import 'channels/prayer_channels.dart';

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

  static String prayerChannelId(int soundMode) =>
      PrayerChannels.channelIdForSoundMode(soundMode);

  static String jamaatChannelId(int soundMode) =>
      JamaatChannels.channelIdForSoundMode(soundMode);

  static String? customSoundResource({
    required String notificationType,
    required int soundMode,
  }) {
    final isPrayer = notificationType == 'prayer';
    return isPrayer
        ? PrayerChannels.customSoundResource(soundMode)
        : JamaatChannels.customSoundResource(soundMode);
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
    return PrayerChannels.buildChannelById(id) ??
        JamaatChannels.buildChannelById(id) ??
        FajrVoiceChannel.buildChannelById(id);
  }

  static const List<String> allChannelIds = <String>[
    ...PrayerChannels.allChannelIds,
    ...JamaatChannels.allChannelIds,
    FajrVoiceChannel.channelId,
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
    await ensureChannelById(FajrVoiceChannel.channelId);
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
