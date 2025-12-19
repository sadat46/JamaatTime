import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class SettingsService {
  static const String _themeKey = 'theme_mode';
  static const String _madhabKey = 'madhab';
  static const String _themeIndexKey = 'theme_index';
  static const String _keyNotificationSoundMode = 'notification_sound_mode';
  static const String _keyPrayerNotificationSoundMode = 'prayer_notification_sound_mode';
  static const String _keyJamaatNotificationSoundMode = 'jamaat_notification_sound_mode';
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

  Future<int> getThemeIndex() async {
    final prefs = await _prefs;
    return prefs.getInt(_themeIndexKey) ?? 0;
  }

  Future<void> setThemeIndex(int idx) async {
    final prefs = await _prefs;
    await prefs.setInt(_themeIndexKey, idx);
    _controller.add(null);
  }

  Future<int> getNotificationSoundMode() async {
    final prefs = await _prefs;
    return prefs.getInt(_keyNotificationSoundMode) ?? 0; // default: custom
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
    return prefs.getInt(_keyPrayerNotificationSoundMode) ?? 0; // default: custom
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
    return prefs.getInt(_keyJamaatNotificationSoundMode) ?? 0; // default: custom
  }

  Future<void> setJamaatNotificationSoundMode(int mode) async {
    final prefs = await _prefs;
    await prefs.setInt(_keyJamaatNotificationSoundMode, mode);
    // Notify listeners that notification settings have changed
    _controller.add(null);
  }
} 