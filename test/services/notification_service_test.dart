import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/core/app_text.dart';

void main() {
  test('Bengali prayer title localizes Fajr notification label', () {
    final bn = AppText.of(const Locale('bn'));
    expect(bn.notification_prayerTitle(bn.prayer_fajr), 'ফজর নামাজ');
  });

  test('English prayer title localizes Fajr notification label', () {
    final en = AppText.of(const Locale('en'));
    expect(en.notification_prayerTitle(en.prayer_fajr), 'Fajr Prayer');
  });
}
