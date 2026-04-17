import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/core/app_locale_controller.dart';
import 'package:jamaat_time/core/locale_prefs.dart';
import 'package:jamaat_time/l10n/app_localizations.dart';
import 'package:jamaat_time/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrapWithLocale(Widget child, Locale locale) {
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

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppLocaleController.bootstrap();
  });

  testWidgets('renders language section with Bengali label by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithLocale(const SettingsScreen(), const Locale('bn')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ভাষা'), findsOneWidget);
    expect(find.text('অ্যাপের ভাষা'), findsOneWidget);
  });

  testWidgets('changing dropdown to English persists and updates controller', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapWithLocale(const SettingsScreen(), const Locale('bn')),
    );
    await tester.pumpAndSettle();

    expect(AppLocaleController.instance.current, const Locale('bn'));

    await tester.tap(find.text('বাংলা').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(AppLocaleController.instance.current, const Locale('en'));
    expect(await LocalePrefs.read(), 'en');
  });
}
