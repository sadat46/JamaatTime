import 'package:flutter/widgets.dart';

bool isEnglishLocale(Locale locale) => locale.languageCode.toLowerCase() == 'en';

bool isEnglishLocaleOf(BuildContext context) =>
    isEnglishLocale(Localizations.localeOf(context));

extension LocaleTextX on BuildContext {
  bool get isEnglish => isEnglishLocaleOf(this);

  String tr({required String bn, required String en}) {
    return isEnglish ? en : bn;
  }
}
