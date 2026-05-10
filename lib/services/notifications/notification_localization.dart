import 'package:flutter/widgets.dart';

import '../../core/app_text.dart';

String localizedPrayerName(Locale locale, String prayerKey) {
  final strings = AppText.of(locale);
  switch (prayerKey) {
    case 'Fajr':
      return strings.prayer_fajr;
    case 'Sunrise':
      return strings.prayer_sunrise;
    case 'Dhuhr':
      return strings.prayer_dhuhr;
    case 'Asr':
      return strings.prayer_asr;
    case 'Maghrib':
      return strings.prayer_maghrib;
    case 'Isha':
      return strings.prayer_isha;
    default:
      return prayerKey;
  }
}
