import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/core/app_text.dart';

void main() {
  test('AppText.of returns Bengali strings for bn locale', () {
    final strings = AppText.of(const Locale('bn'));
    expect(strings.prayer_fajr, 'ফজর');
    expect(strings.nav_home, 'হোম');
  });

  test('AppText.of returns English strings for en locale', () {
    final strings = AppText.of(const Locale('en'));
    expect(strings.prayer_fajr, 'Fajr');
    expect(strings.nav_home, 'Home');
  });
}
