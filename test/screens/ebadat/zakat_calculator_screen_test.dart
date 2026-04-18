import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/screens/ebadat/topics/zakat_calculator_screen.dart';

Widget _wrap(Widget child, Locale locale) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('bn'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

void main() {
  testWidgets('zakat screen shows English UI labels in en locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const ZakatCalculatorScreen(), const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zakat'), findsOneWidget);
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Guidelines'), findsOneWidget);
    expect(find.text('Calculate Zakat'), findsOneWidget);
  });

  testWidgets('zakat screen hides English tab label in bn locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const ZakatCalculatorScreen(), const Locale('bn')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calculator'), findsNothing);
    expect(find.text('Guidelines'), findsNothing);
  });
}
