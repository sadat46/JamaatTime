import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/l10n/app_localizations.dart';
import 'package:jamaat_time/models/monajat_model.dart';
import 'package:jamaat_time/screens/ebadat/topics/monajat_detail_screen.dart';

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

MonajatModel _sampleMonajat() {
  return const MonajatModel(
    id: 1,
    title: 'Bangla Title',
    arabic: '?????????? ???????',
    pronunciation: 'Alhamdu lillah',
    meaning: 'Bangla Meaning',
    context: 'Bangla Context',
    titleEnglish: 'Dua After Waking Up',
    meaningEnglish: 'All praise is for Allah.',
    contextEnglish: 'Recite after waking from sleep.',
  );
}

void main() {
  testWidgets('monajat detail shows localized labels in bn locale', (
    tester,
  ) async {
    const locale = Locale('bn');
    final strings = lookupAppLocalizations(locale);

    await tester.pumpWidget(
      _wrapWithLocale(
        MonajatDetailScreen(monajat: _sampleMonajat()),
        locale,
      ),
    );

    expect(find.text('Bangla Title'), findsNWidgets(2));
    expect(find.text(strings.ebadat_monajatPronunciationLabel), findsOneWidget);
    expect(find.text(strings.ebadat_monajatMeaningLabel), findsOneWidget);
    expect(find.text(strings.ebadat_monajatContextLabel), findsOneWidget);
    expect(find.text(strings.ebadat_monajatCopyButton), findsOneWidget);
  });

  testWidgets('monajat detail shows localized labels in en locale', (
    tester,
  ) async {
    const locale = Locale('en');
    final strings = lookupAppLocalizations(locale);

    await tester.pumpWidget(
      _wrapWithLocale(
        MonajatDetailScreen(monajat: _sampleMonajat()),
        locale,
      ),
    );

    expect(find.text('Dua After Waking Up'), findsNWidgets(2));
    expect(find.text(strings.ebadat_monajatPronunciationLabel), findsOneWidget);
    expect(find.text(strings.ebadat_monajatMeaningLabel), findsOneWidget);
    expect(find.text(strings.ebadat_monajatContextLabel), findsOneWidget);
    expect(find.text(strings.ebadat_monajatCopyButton), findsOneWidget);
  });
}
