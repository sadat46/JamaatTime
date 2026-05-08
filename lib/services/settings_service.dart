import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../core/locale_prefs.dart';

class SettingsService {
  static const int defaultBangladeshHijriOffsetDays = -1;

  static const String _themeKey = 'theme_mode';
  static const String _madhabKey = 'madhab';
  static const String _localeKey = 'app_locale';
  static const String _themeIndexKey = 'theme_index';
  static const String _keyNotificationSoundMode = 'notification_sound_mode';
  static const String _keyPrayerNotificationSoundMode =
      'prayer_notification_sound_mode';
  static const String _keyJamaatNotificationSoundMode =
      'jamaat_notification_sound_mode';
  static const String _keyFajrVoiceNotificationEnabled =
      'fajr_voice_notification_enabled';
  static const String _keyNotificationSoundDefaultMigratedV2 =
      'notification_sound_default_migrated_v2';
  static const String _keyBangladeshHijriOffsetDays =
      'bangladesh_hijri_offset_days';
  static const String _keyAutoVibrationEnabled = 'auto_vibration_enabled';
  static const String _keyAutoVibrationMinutesBefore =
      'auto_vibration_minutes_before';
  static const String _keyAutoVibrationMinutesAfter =
      'auto_vibration_minutes_after';
  static const int defaultAutoVibrationMinutesBefore = 5;
  static const int defaultAutoVibrationMinutesAfter = 15;
  static const int maxAutoVibrationMinutesBefore = 20;
  static const int maxAutoVibrationMinutesAfter = 25;
  static const int _defaultNotificationSoundMode = 3; // Custom 2 sound
  final StreamController<void> _controller = StreamController.broadcast();

  // Cached SharedPreferences instance
  static SharedPreferences? _prefsInstance;

  Stream<void> get onSettingsChanged => _controller.stream;

  /// Get cached SharedPreferences instance (reduces disk I/O)
  Future<SharedPreferences> get _prefs async {
    _prefsInstance ??= await SharedPreferences.getInstance();
    return _prefsInstance!;
  }

  Future<bool> isDarkMode() async {
    final prefs = await _prefs;
    return prefs.getString(_themeKey) == 'dark';
  }

  Future<void> setDarkMode(bool dark) async {
    final prefs = await _prefs;
    await prefs.setString(_themeKey, dark ? 'dark' : 'light');
    _controller.add(null);
  }

  Future<String> getMadhab() async {
    final prefs = await _prefs;
    return prefs.getString(_madhabKey) ?? 'hanafi';
  }

  Future<void> setMadhab(String madhab) async {
    final prefs = await _prefs;
    await prefs.setString(_madhabKey, madhab);
    _controller.add(null);
  }

  Future<String> getLocale() async {
    final prefs = await _prefs;
    return prefs.getString(_localeKey) ?? LocalePrefs.defaultCode;
  }

  Future<void> setLocale(String code) async {
    assert(_localeKey == LocalePrefs.key, 'locale key parity');
    final prefs = await _prefs;
    await prefs.setString(_localeKey, code);
    _controller.add(null);
  }

  Future<int> getThemeIndex() async {
    final prefs = await _prefs;
    return prefs.getInt(_themeIndexKey) ?? 2;
  }

  Future<void> setThemeIndex(int idx) async {
    final prefs = await _prefs;
    await prefs.setInt(_themeIndexKey, idx);
    _controller.add(null);
  }

  Future<int> getNotificationSoundMode() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyNotificationSoundMode) ??
        _defaultNotificationSoundMode;
  }

  Future<void> setNotificationSoundMode(int mode) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyNotificationSoundMode, mode);
    // Notify listeners that notification settings have changed
    _controller.add(null);
  }

  // Prayer notification sound mode methods
  Future<int> getPrayerNotificationSoundMode() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyPrayerNotificationSoundMode) ??
        _defaultNotificationSoundMode;
  }

  Future<void> setPrayerNotificationSoundMode(int mode) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyPrayerNotificationSoundMode, mode);
    // Notify listeners that notification settings have changed
    _controller.add(null);
  }

  // Jamaat notification sound mode methods
  Future<int> getJamaatNotificationSoundMode() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyJamaatNotificationSoundMode) ??
        _defaultNotificationSoundMode;
  }

  Future<void> setJamaatNotificationSoundMode(int mode) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyJamaatNotificationSoundMode, mode);
    // Notify listeners that notification settings have changed
    _controller.add(null);
  }

  Future<bool> getFajrVoiceNotificationEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyFajrVoiceNotificationEnabled) ?? false;
  }

  Future<void> setFajrVoiceNotificationEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyFajrVoiceNotificationEnabled, enabled);
    _controller.add(null);
  }

  /// One-time migration to switch default notification sound to Custom 2.
  Future<void> migrateNotificationSoundDefaultsToCustom2() async {
    final prefs = await _prefs;
    final hasMigrated =
        prefs.getBool(_keyNotificationSoundDefaultMigratedV2) ?? false;
    if (hasMigrated) {
      return;
    }

    await prefs.setInt(
      _keyPrayerNotificationSoundMode,
      _defaultNotificationSoundMode,
    );
    await prefs.setInt(
      _keyJamaatNotificationSoundMode,
      _defaultNotificationSoundMode,
    );
    await prefs.setInt(
      _keyNotificationSoundMode,
      _defaultNotificationSoundMode,
    );
    await prefs.setBool(_keyNotificationSoundDefaultMigratedV2, true);
    _controller.add(null);
  }

  Future<int> getBangladeshHijriOffsetDays() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyBangladeshHijriOffsetDays) ??
        defaultBangladeshHijriOffsetDays;
  }

  Future<void> setBangladeshHijriOffsetDays(int days) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyBangladeshHijriOffsetDays, days);
    _controller.add(null);
  }

  Future<bool> getAutoVibrationEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyAutoVibrationEnabled) ?? false;
  }

  Future<void> setAutoVibrationEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyAutoVibrationEnabled, enabled);
    _controller.add(null);
  }

  Future<int> getAutoVibrationMinutesBefore() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyAutoVibrationMinutesBefore) ??
        defaultAutoVibrationMinutesBefore;
  }

  Future<void> setAutoVibrationMinutesBefore(int minutes) async {
    final clamped = minutes.clamp(0, maxAutoVibrationMinutesBefore);
    final prefs = await _prefs;
    await prefs.setInt(_keyAutoVibrationMinutesBefore, clamped);
    _controller.add(null);
  }

  Future<int> getAutoVibrationMinutesAfter() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyAutoVibrationMinutesAfter) ??
        defaultAutoVibrationMinutesAfter;
  }

  Future<void> setAutoVibrationMinutesAfter(int minutes) async {
    final clamped = minutes.clamp(0, maxAutoVibrationMinutesAfter);
    final prefs = await _prefs;
    await prefs.setInt(_keyAutoVibrationMinutesAfter, clamped);
    _controller.add(null);
  }
}
