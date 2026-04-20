import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/core/app_locale_controller.dart';
import 'package:jamaat_time/core/locale_prefs.dart';
import 'package:jamaat_time/screens/settings_screen.dart';

import '../helpers/localized_test_wrapper.dart';

void main() {
  setUp(() async {
    await seedMockLocalePrefs('bn');
  });

  testWidgets('renders language section with Bengali label by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithLocale(child: const SettingsScreen(), locale: const Locale('bn')),
    );
    await tester.pumpAndSettle();

    expect(find.text('ভাষা'), findsOneWidget);
    expect(find.text('অ্যাপের ভাষা'), findsOneWidget);
  });

  testWidgets('changing dropdown to English persists and updates controller', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithLocale(child: const SettingsScreen(), locale: const Locale('bn')),
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
