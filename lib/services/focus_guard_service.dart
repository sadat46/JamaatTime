import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/monajat_data.dart';
import '../models/focus_guard_settings.dart';
import '../models/monajat_model.dart';

class FocusGuardService {
  static final FocusGuardService _instance = FocusGuardService._internal();
  factory FocusGuardService() => _instance;
  FocusGuardService._internal();

  static const String _prefsKey = 'focus_guard_settings';
  static const String _accessibilityDisclosureKey =
      'focus_guard_accessibility_disclosure_accepted';
  static const MethodChannel _channel = MethodChannel(
    'jamaat_time/focus_guard',
  );
  final Random _random = Random();

  Future<FocusGuardSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return const FocusGuardSettings();
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return FocusGuardSettings.fromJson(map);
    } catch (_) {
      return const FocusGuardSettings();
    }
  }

  Future<void> saveSettings(FocusGuardSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(settings.toJson());
    await prefs.setString(_prefsKey, encoded);
    await syncSettingsToNative(settings);
  }

  Future<bool> hasAccessibilityDisclosureConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_accessibilityDisclosureKey) ?? false;
  }

  Future<void> setAccessibilityDisclosureConsent(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_accessibilityDisclosureKey, accepted);
  }

  Future<void> syncSettingsToNative(FocusGuardSettings settings) async {
    try {
      await _channel.invokeMethod<void>('updateSettings', {
        'json': jsonEncode(settings.toJson()),
      });
    } on MissingPluginException {
      // No-op on platforms without native implementation.
    } on PlatformException {
      // No-op on channel failures.
    }
  }

  Future<Map<String, bool>> getPermissionStatus() async {
    try {
      final accessibility =
          await _channel.invokeMethod<bool>('isAccessibilityEnabled') ?? false;
      return {'accessibility': accessibility};
    } on MissingPluginException {
      return {'accessibility': false};
    } on PlatformException {
      return {'accessibility': false};
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod<void>('openAccessibilitySettings');
    } on MissingPluginException {
      // No-op.
    } on PlatformException {
      // No-op.
    }
  }

  MonajatModel getRandomMunajat() {
    return allMonajatList[_random.nextInt(allMonajatList.length)];
  }
}
