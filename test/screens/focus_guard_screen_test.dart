import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/screens/focus_guard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('jamaat_time/focus_guard');
  Object? lastNativeSettingsUpdate;

  setUp(() {
    lastNativeSettingsUpdate = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'isAccessibilityEnabled':
              return true;
            case 'updateSettings':
              lastNativeSettingsUpdate = call.arguments;
              return null;
            case 'openAccessibilitySettings':
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('shows quick allow settings and saves selected minutes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'focus_guard_settings': jsonEncode({
        'enabled': true,
        'blockedApps': {'youtube': true},
        'tempAllowMinutes': 10,
        'quickAllowEnabled': true,
      }),
    });

    await tester.pumpWidget(const MaterialApp(home: FocusGuardScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Allow quick bypass'),
      180,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('Allow quick bypass'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);

    await tester.ensureVisible(find.text('15 min'));
    await tester.tap(find.text('15 min'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final saved =
        jsonDecode(prefs.getString('focus_guard_settings')!)
            as Map<String, dynamic>;
    expect(saved['tempAllowMinutes'], 15);
    expect(saved['quickAllowEnabled'], true);

    final nativeUpdate = lastNativeSettingsUpdate as Map<Object?, Object?>?;
    expect(nativeUpdate?['json'], contains('"tempAllowMinutes":15'));
  });
}
