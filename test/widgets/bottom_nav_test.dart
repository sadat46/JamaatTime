import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/l10n/app_localizations.dart';
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget harness(Locale locale) {
    final nav = Builder(
      builder: (context) {
        final strings = AppLocalizations.of(context);
        return BottomNavigationBar(
          currentIndex: 0,
          onTap: (_) {},
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home),
              label: strings.nav_home,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.mosque),
              label: strings.nav_ebadat,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_month),
              label: strings.nav_calendar,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person),
              label: strings.nav_profile,
            ),
          ],
        );
      },
    );
    return _wrapWithLocale(Scaffold(bottomNavigationBar: nav), locale);
  }

  testWidgets('bottom nav renders Bengali labels for bn locale', (
    tester,
  ) async {
    await tester.pumpWidget(harness(const Locale('bn')));
    expect(find.text('হোম'), findsOneWidget);
    expect(find.text('ইবাদত'), findsOneWidget);
    expect(find.text('ক্যালেন্ডার'), findsOneWidget);
    expect(find.text('প্রোফাইল'), findsOneWidget);
  });

  testWidgets('bottom nav renders English labels for en locale', (
    tester,
  ) async {
    await tester.pumpWidget(harness(const Locale('en')));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Ebadat'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
