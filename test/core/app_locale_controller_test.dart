import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/core/app_locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('bootstrap() reads the persisted locale', () async {
    SharedPreferences.setMockInitialValues({'app_locale': 'en'});
    await AppLocaleController.bootstrap();
    expect(AppLocaleController.instance.current, const Locale('en'));
  });

  test('bootstrap() falls back to bn when nothing is persisted', () async {
    await AppLocaleController.bootstrap();
    expect(AppLocaleController.instance.current, const Locale('bn'));
  });

  test('set() updates the notifier and persists to SharedPreferences',
      () async {
    await AppLocaleController.bootstrap();
    var notified = 0;
    AppLocaleController.instance.notifier.addListener(() => notified++);

    await AppLocaleController.instance.set('en');

    expect(AppLocaleController.instance.current, const Locale('en'));
    expect(notified, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_locale'), 'en');
  });
}
