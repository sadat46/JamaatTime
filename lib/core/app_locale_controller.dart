import 'package:flutter/widgets.dart';

import 'locale_prefs.dart';

/// UI-thread locale controller. MaterialApp rebuilds via
/// `ValueListenableBuilder<Locale>` on [notifier]. Background isolates
/// must not use this — they read prefs through [LocalePrefs] directly.
class AppLocaleController {
  AppLocaleController._(this.notifier);

  static late AppLocaleController instance;

  final ValueNotifier<Locale> notifier;

  Locale get current => notifier.value;

  static Future<void> bootstrap() async {
    final code = await LocalePrefs.read();
    instance = AppLocaleController._(
      ValueNotifier<Locale>(LocalePrefs.toLocale(code)),
    );
  }

  Future<void> set(String code) async {
    await LocalePrefs.write(code);
    notifier.value = LocalePrefs.toLocale(code);
  }
}
