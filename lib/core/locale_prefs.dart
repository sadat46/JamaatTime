import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Isolate-safe locale access. The UI controller and the home-widget
/// background isolate both read the same key through this helper — no
/// cross-isolate singleton.
class LocalePrefs {
  static const String key = 'app_locale';
  static const String defaultCode = 'en';

  static String readFromPrefs(SharedPreferences prefs) =>
      prefs.getString(key) ?? defaultCode;

  static Future<String> read() async =>
      readFromPrefs(await SharedPreferences.getInstance());

  static Future<void> write(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, code);
  }

  static Locale toLocale(String code) =>
      code == 'bn' ? const Locale('bn') : const Locale('en');
}
