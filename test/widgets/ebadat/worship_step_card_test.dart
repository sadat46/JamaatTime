import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/l10n/app_localizations.dart';
import 'package:jamaat_time/models/worship_guide_model.dart';
import 'package:jamaat_time/widgets/ebadat/reference_chip.dart';
import 'package:jamaat_time/widgets/ebadat/worship_step_card.dart';

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
    home: Scaffold(body: child),
  );
}

WorshipStep _sampleStep() {
  return const WorshipStep(
    stepNumber: 1,
    titleBangla: 'Step Bangla',
    titleEnglish: 'Step English',
    transliteration: 'Alhamdu',
    meaning: 'Bangla Meaning',
    meaningEnglish: 'English Meaning',
    instruction: 'Bangla Instruction',
    instructionEnglish: 'English Instruction',
  );
}

void main() {
  testWidgets('worship step card uses localized labels in English', (
    tester,
  ) async {
    const locale = Locale('en');
    final strings = lookupAppLocalizations(locale);

    await tester.pumpWidget(
      _wrapWithLocale(WorshipStepCard(step: _sampleStep()), locale),
    );

    expect(find.text(strings.ebadat_transliterationLabel), findsOneWidget);
    expect(find.text(strings.ebadat_meaningLabel), findsOneWidget);
    expect(find.text('Step English'), findsOneWidget);
    expect(find.text('English Meaning'), findsOneWidget);
    expect(find.text('English Instruction'), findsOneWidget);
  });

  testWidgets('reference section uses localized default title', (tester) async {
    const locale = Locale('en');
    final strings = lookupAppLocalizations(locale);

    await tester.pumpWidget(
      _wrapWithLocale(
        ReferenceSection(
          references: const [
            Reference(source: 'Quran', citation: '2:238'),
          ],
        ),
        locale,
      ),
    );

    expect(find.text(strings.ebadat_referencesTitle), findsOneWidget);
  });
}
