import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationPermissionService {
  NotificationPermissionService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _exactAlarmsAvailable = false;

  bool get exactAlarmsAvailable => _exactAlarmsAvailable;

  AndroidScheduleMode get androidScheduleMode => _exactAlarmsAvailable
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  AndroidFlutterLocalNotificationsPlugin? _androidPlugin() => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> requestNotificationsPermission() async {
    if (!Platform.isAndroid) return;
    final androidImplementation = _androidPlugin();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  Future<bool> refreshExactAlarmsAvailable() async {
    if (!Platform.isAndroid) {
      _exactAlarmsAvailable = true;
      return true;
    }
    try {
      final granted =
          await _androidPlugin()?.canScheduleExactNotifications() ?? false;
      _exactAlarmsAvailable = granted;
      return granted;
    } catch (e) {
      developer.log(
        'canScheduleExactNotifications failed: $e',
        name: 'NotificationService',
      );
      _exactAlarmsAvailable = false;
      return false;
    }
  }

  Future<bool> requestExactAlarmsPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final result =
          await _androidPlugin()?.requestExactAlarmsPermission() ?? false;
      _exactAlarmsAvailable = result;
      return result;
    } catch (e) {
      developer.log(
        'requestExactAlarmsPermission failed: $e',
        name: 'NotificationService',
      );
      return false;
    }
  }

  Future<bool> areNotificationsEnabled() async {
    try {
      final androidImplementation = _androidPlugin();
      if (androidImplementation != null) {
        return await androidImplementation.areNotificationsEnabled() ?? false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
