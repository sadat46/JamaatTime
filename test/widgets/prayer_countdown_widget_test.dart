import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/l10n/app_localizations.dart';
import 'package:jamaat_time/widgets/prayer_countdown_widget.dart';

Widget _buildHarness({
  required Locale locale,
  required DateTime selectedDate,
  required Map<String, DateTime?> prayerTimes,
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
    home: Scaffold(
      body: PrayerCountdownWidget(
        prayerTimes: prayerTimes,
        selectedDate: selectedDate,
      ),
    ),
  );
}

Map<String, DateTime?> _samplePrayerTimesFor(DateTime date) {
  DateTime at(int hour, int minute) =>
      DateTime(date.year, date.month, date.day, hour, minute);

  return {
    'Fajr': at(5, 0),
    'Sunrise': at(6, 15),
    'Dhuhr': at(12, 10),
    'Asr': at(15, 40),
    'Maghrib': at(18, 25),
    'Isha': at(19, 40),
  };
}

void main() {
  testWidgets('does not access localization too early during init lifecycle', (
    tester,
  ) async {
    final now = DateTime.now();
    final selectedDate = DateTime(now.year, now.month, now.day);
    final prayerTimes = _samplePrayerTimesFor(selectedDate);

    await tester.pumpWidget(
      _buildHarness(
        locale: const Locale('en'),
        selectedDate: selectedDate,
        prayerTimes: prayerTimes,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(PrayerCountdownWidget), findsOneWidget);
  });
}
