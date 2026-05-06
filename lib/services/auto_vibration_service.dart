import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'settings_service.dart';

/// Schedules native AlarmManager-driven ringer-mode toggles around each
/// jamaat time. Android-only; on iOS every method is a no-op.
class AutoVibrationService {
  AutoVibrationService._();
  static final AutoVibrationService _instance = AutoVibrationService._();
  factory AutoVibrationService() => _instance;

  static const MethodChannel _channel = MethodChannel(
    'jamaat_time/auto_vibration',
  );

  final SettingsService _settings = SettingsService();

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  Future<bool> hasDndAccess() async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hasDndAccess');
      return result ?? false;
    } on PlatformException catch (e) {
      developer.log(
        'hasDndAccess failed: $e',
        name: 'AutoVibrationService',
        error: e,
      );
      return false;
    }
  }

  Future<void> openDndSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openDndSettings');
    } on PlatformException catch (e) {
      developer.log(
        'openDndSettings failed: $e',
        name: 'AutoVibrationService',
        error: e,
      );
    }
  }

  Future<void> cancelAll() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('cancelAll');
    } on PlatformException catch (e) {
      developer.log(
        'cancelAll failed: $e',
        name: 'AutoVibrationService',
        error: e,
      );
    }
  }

  /// Build today's vibration windows from jamaat HH:mm strings and ship the
  /// schedule to the native side. If the feature toggle is off, cancels
  /// any previously-scheduled alarms instead.
  Future<void> reschedule(Map<String, dynamic>? jamaatTimes) async {
    if (!_isAndroid) return;

    final enabled = await _settings.getAutoVibrationEnabled();
    if (!enabled) {
      await cancelAll();
      return;
    }

    if (jamaatTimes == null || jamaatTimes.isEmpty) {
      await cancelAll();
      return;
    }

    final minutesBefore = await _settings.getAutoVibrationMinutesBefore();
    final minutesAfter = await _settings.getAutoVibrationMinutesAfter();

    final now = DateTime.now();
    final windows = <Map<String, dynamic>>[];

    for (final entry in jamaatTimes.entries) {
      final canonical = _canonicalPrayer(entry.key);
      if (canonical == null) continue;

      final value = entry.value;
      if (value is! String || value.isEmpty || value == '-') continue;

      final parts = value.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) continue;

      final jamaat = DateTime(now.year, now.month, now.day, hour, minute);
      final start = jamaat.subtract(Duration(minutes: minutesBefore));
      final end = jamaat.add(Duration(minutes: minutesAfter));

      // Drop windows whose end has already passed.
      if (!end.isAfter(now)) continue;

      windows.add({
        'prayer': canonical,
        'startEpoch': start.millisecondsSinceEpoch,
        'endEpoch': end.millisecondsSinceEpoch,
      });
    }

    try {
      await _channel.invokeMethod<void>('schedule', {'windows': windows});
    } on PlatformException catch (e) {
      developer.log(
        'schedule failed: $e',
        name: 'AutoVibrationService',
        error: e,
      );
    }
  }

  String? _canonicalPrayer(String key) {
    switch (key.toLowerCase()) {
      case 'fajr':
        return 'fajr';
      case 'dhuhr':
      case 'zuhr':
        return 'dhuhr';
      case 'asr':
        return 'asr';
      case 'maghrib':
      case 'magrib':
        return 'maghrib';
      case 'isha':
        return 'isha';
      default:
        return null;
    }
  }
}

