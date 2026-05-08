import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/widgets/calendar_selected_date_card.dart';

import '../helpers/localized_test_wrapper.dart';

Widget _testHost({
  required Widget child,
  ThemeData? theme,
  double width = 360,
  Locale locale = const Locale('en'),
}) {
  return wrapWithLocale(
    locale: locale,
    child: Theme(
      data: theme ?? ThemeData.light(),
      child: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

CalendarSelectedDateCard _buildCard() {
  return const CalendarSelectedDateCard(
    gregorianDate: '14 Apr 2026',
    weekday: 'Tuesday',
    banglaDate: '1 Boishakh 1433 Bongabdo',
    hijriDate: '25 Shawwal 1447 AH',
    cardBackground: Colors.white,
    borderColor: Colors.green,
  );
}

Finder _richTextContaining(String text) {
  return find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText().contains(text),
  );
}

void main() {
  const localizedHeaderDate = '\u09E7\u09EA Apr \u09E8\u09E6\u09E8\u09EC';

  testWidgets(
    'shows Gregorian header and normalized date chips without labels',
    (WidgetTester tester) async {
      await tester.pumpWidget(_testHost(child: _buildCard()));

      expect(_richTextContaining('14 Apr 2026'), findsAtLeastNWidgets(1));
      expect(_richTextContaining('Tuesday'), findsOneWidget);
      expect(find.text('1 Boishakh 1433'), findsOneWidget);
      expect(find.text('25 Shawwal 1447'), findsOneWidget);
      expect(find.text('Bangla'), findsNothing);
      expect(find.text('Hijri'), findsNothing);
      expect(find.text('English'), findsNothing);
    },
  );

  testWidgets('hides localized chip labels in Bengali locale', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testHost(child: _buildCard(), locale: const Locale('bn')),
    );
    expect(_richTextContaining(localizedHeaderDate), findsAtLeastNWidgets(1));

    expect(find.text('ইংরেজি'), findsNothing);
    expect(find.text('বাংলা'), findsNothing);
    expect(find.text('হিজরি'), findsNothing);
  });

  testWidgets('header RichText inherits themed font family', (
    WidgetTester tester,
  ) async {
    const fontFamily = 'TestBanglaFont';
    final theme = ThemeData(
      textTheme: const TextTheme(bodyMedium: TextStyle(fontFamily: fontFamily)),
    );

    await tester.pumpWidget(
      _testHost(child: _buildCard(), theme: theme, locale: const Locale('bn')),
    );

    final headerRichTextFinder = _richTextContaining(localizedHeaderDate).first;
    final headerRichText = tester.widget<RichText>(headerRichTextFinder);
    expect(headerRichText.text.style?.fontFamily, fontFamily);
  });

  testWidgets('adds semantic labels for selected, Bangla, and Hijri dates', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testHost(child: _buildCard()));

    final cardSemantics = tester.getSemantics(
      find.byType(CalendarSelectedDateCard),
    );
    expect(
      cardSemantics.label,
      contains(
        'Selected date 14 Apr 2026, Tuesday. Bangla 1 Boishakh 1433. Hijri 25 Shawwal 1447.',
      ),
    );
    expect(cardSemantics.label, contains('Bangla date 1 Boishakh 1433'));
    expect(cardSemantics.label, contains('Hijri date 25 Shawwal 1447'));
  });

  testWidgets('stays stable on narrow widths without overflow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testHost(width: 220, child: _buildCard()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders in dark theme', (WidgetTester tester) async {
    await tester.pumpWidget(
      _testHost(theme: ThemeData.dark(), child: _buildCard()),
    );

    expect(_richTextContaining('14 Apr 2026'), findsAtLeastNWidgets(1));
    expect(find.text('1 Boishakh 1433'), findsOneWidget);
    expect(find.text('25 Shawwal 1447'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
