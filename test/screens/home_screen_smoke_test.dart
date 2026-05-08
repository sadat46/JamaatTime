import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/screens/home/home_controller.dart';
import 'package:jamaat_time/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/localized_test_wrapper.dart';

void main() {
  testWidgets('HomeScreen renders without throwing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = HomeController(isActive: false);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrapWithLocale(
        child: HomeScreen(
          isActive: false,
          controller: controller,
          noticeAction: const SizedBox(width: 44, height: 44),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Jamaat Time'), findsOneWidget);
  });
}
