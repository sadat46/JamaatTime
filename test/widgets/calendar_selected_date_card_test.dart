import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/widgets/calendar_selected_date_card.dart';

Widget _testHost({
  required Widget child,
  ThemeData? theme,
  double width = 360,
}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
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

void main() {
  testWidgets('shows Gregorian header and only Bangla/Hijri chips', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testHost(child: _buildCard()));

    expect(find.text('14 Apr 2026'), findsOneWidget);
    expect(find.text('Tuesday'), findsOneWidget);
    expect(find.text('Bangla'), findsOneWidget);
    expect(find.text('Hijri'), findsOneWidget);
    expect(find.text('1 Boishakh'), findsOneWidget);
    expect(find.text('1433 Bongabdo'), findsOneWidget);
    expect(find.text('25 Shawwal'), findsOneWidget);
    expect(find.text('1447 AH'), findsOneWidget);
    expect(find.text('English'), findsNothing);
  });

  testWidgets('adds semantic labels for selected, Bangla, and Hijri dates', (
    WidgetTester tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    await tester.pumpWidget(_testHost(child: _buildCard()));

    expect(
      find.bySemanticsLabel(
        'Selected date 14 Apr 2026, Tuesday. Bangla 1 Boishakh 1433 Bongabdo. Hijri 25 Shawwal 1447 AH.',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Bangla date 1 Boishakh 1433 Bongabdo'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Hijri date 25 Shawwal 1447 AH'),
      findsOneWidget,
    );
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

    expect(find.text('14 Apr 2026'), findsOneWidget);
    expect(find.text('Bangla'), findsOneWidget);
    expect(find.text('Hijri'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
