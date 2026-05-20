import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/services/notifications/notification_ids.dart';
import 'package:jamaat_time/widgets/notifications/notification_history_row.dart';

void main() {
  group('NotificationIds.broadcast', () {
    test('is deterministic for the same notifId', () {
      expect(
        NotificationIds.broadcast('abc123'),
        NotificationIds.broadcast('abc123'),
      );
    });

    test('stays in its dedicated range, clear of reminder ranges', () {
      const base = 4000000;
      for (final id in ['n1', 'another-notif', 'x' * 64, '0']) {
        final value = NotificationIds.broadcast(id);
        expect(value, greaterThanOrEqualTo(base));
        expect(value, lessThanOrEqualTo(base + 0x7FFFFF));
        // No overlap with prayer/jamaat/fajr ranges (1101-3102).
        expect(value, greaterThan(3102));
      }
    });

    test('differs for different notifIds', () {
      expect(
        NotificationIds.broadcast('alpha'),
        isNot(NotificationIds.broadcast('beta')),
      );
    });
  });

  group('NotificationHistoryRow remove action', () {
    Future<void> pumpRow(WidgetTester tester, String status) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('bn')],
          home: Scaffold(
            body: ListView(
              children: [
                NotificationHistoryRow(
                  notifId: 'notif-1',
                  data: {
                    'status': status,
                    'title': 'Hello',
                    'body': 'World',
                  },
                  legacy: false,
                  onRetry: (_) async {},
                  onCancel: (_) async {},
                  onRemove: (_) async {},
                  onViewRaw: () {},
                  busy: false,
                ),
              ],
            ),
          ),
        ),
      );
      // Actions live inside the collapsible body — expand the tile.
      await tester.tap(find.byKey(const ValueKey('notif-row-notif-1')));
      await tester.pumpAndSettle();
    }

    testWidgets('shows Remove for a sent notice', (tester) async {
      await pumpRow(tester, 'sent');
      expect(find.text('Remove from notice board'), findsOneWidget);
    });

    testWidgets('hides Remove for an already-removed notice', (tester) async {
      await pumpRow(tester, 'removed');
      expect(find.text('Remove from notice board'), findsNothing);
    });
  });
}
