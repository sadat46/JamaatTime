import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/widgets/sahri_iftar_widget.dart';

void main() {
  Widget buildTestWidget({
    required DateTime? fajrTime,
    required DateTime? maghribTime,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SahriIftarWidget(fajrTime: fajrTime, maghribTime: maghribTime),
      ),
    );
  }

  testWidgets('renders Sahri and Iftar as separate cards', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      buildTestWidget(
        fajrTime: now.add(const Duration(hours: 2)),
        maghribTime: now.add(const Duration(hours: 8)),
      ),
    );

    expect(find.byKey(const Key('sahri-card')), findsOneWidget);
    expect(find.byKey(const Key('iftar-card')), findsOneWidget);
    expect(find.text('Sahri Ends'), findsOneWidget);
    expect(find.text('Iftar Begins'), findsOneWidget);
    expect(find.text('Remaining Time'), findsNWidgets(2));
    expect(find.text('Focus'), findsNWidgets(2));
    expect(find.textContaining('Ends at'), findsOneWidget);
    expect(find.textContaining('Begins at'), findsOneWidget);
  });

  testWidgets('tapping a card opens fullscreen and can close', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      buildTestWidget(
        fajrTime: now.add(const Duration(hours: 2)),
        maghribTime: now.add(const Duration(hours: 8)),
      ),
    );

    await tester.tap(find.byKey(const Key('sahri-card')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sahri-fullscreen')), findsOneWidget);
    expect(find.text('Sahri Focus'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sahri-fullscreen')), findsNothing);
    expect(find.byKey(const Key('sahri-card')), findsOneWidget);
  });
}
