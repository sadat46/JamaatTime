import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/website_protection_settings.dart';

class FamilySafetyStorage {
  static const String settingsKey = 'family_safety_settings';

  Future<WebsiteProtectionSettings> loadWebsiteProtectionSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(settingsKey);
    if (raw == null || raw.isEmpty) {
      return const WebsiteProtectionSettings();
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      return const WebsiteProtectionSettings();
    }
    return WebsiteProtectionSettings.fromJson(decoded);
  }

  Future<void> saveWebsiteProtectionSettings(
    WebsiteProtectionSettings settings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsKey, jsonEncode(settings.toJson()));
  }
}
