import 'package:flutter/widgets.dart';

import 'bangla_calendar.dart';

/// Localizes Western digits to locale-specific numerals for UI display.
class LocaleDigits {
  LocaleDigits._();

  static String localize(String text, Locale locale) {
    if (locale.languageCode.toLowerCase() == 'bn') {
      return BanglaCalendar.toBanglaDigits(text);
    }
    return text;
  }
}
