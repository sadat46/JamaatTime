import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jamaat_time/core/app_locale_controller.dart';
import 'package:jamaat_time/core/locale_prefs.dart';
import 'package:jamaat_time/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget wrapWithLocale({
  required Widget child,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

Future<void> seedMockLocalePrefs([String localeCode = 'en']) async {
  SharedPreferences.setMockInitialValues({LocalePrefs.key: localeCode});
  await AppLocaleController.bootstrap();
}
