// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get nav_home => 'Home';

  @override
  String get nav_ebadat => 'Ebadat';

  @override
  String get nav_calendar => 'Calendar';

  @override
  String get nav_profile => 'Profile';

  @override
  String get settings_languageSection => 'Language';

  @override
  String get settings_languageSubtitle => 'Choose the app display language.';

  @override
  String get settings_languageLabel => 'App language';

  @override
  String get settings_languageBangla => 'বাংলা';

  @override
  String get settings_languageEnglish => 'English';

  @override
  String get widget_jamaatNA => 'Jamaat N/A';

  @override
  String get widget_jamaatOver => 'Jamaat is Over';

  @override
  String get widget_jamaatInSuffix => 'Jamaat in';

  @override
  String get widget_comingDhuhr => 'Coming Dhuhr';

  @override
  String widget_timeRemaining(String prayer) {
    return '$prayer Time Remaining';
  }

  @override
  String get prayer_fajr => 'Fajr';

  @override
  String get prayer_sunrise => 'Sunrise';

  @override
  String get prayer_dhuhr => 'Dhuhr';

  @override
  String get prayer_asr => 'Asr';

  @override
  String get prayer_maghrib => 'Maghrib';

  @override
  String get prayer_isha => 'Isha';

  @override
  String notification_prayerTitle(String prayer) {
    return '$prayer Prayer';
  }

  @override
  String notification_prayerBody(String prayer) {
    return '$prayer time remaining 20 minutes.';
  }

  @override
  String notification_jamaatTitle(String prayer) {
    return '$prayer Jamaat';
  }

  @override
  String notification_jamaatBody(String prayer) {
    return '$prayer Jamaat is in 10 minutes.';
  }

  @override
  String get ebadat_monajatCopyTooltip => 'Copy';

  @override
  String get ebadat_monajatPronunciationLabel => 'Pronunciation';

  @override
  String get ebadat_monajatMeaningLabel => 'Meaning';

  @override
  String get ebadat_monajatContextLabel => 'Context & Benefit';

  @override
  String get ebadat_monajatContextShortLabel => 'Context';

  @override
  String get ebadat_monajatCopyButton => 'Copy Full Dua';

  @override
  String get ebadat_monajatCopySuccess => 'Copied to clipboard';

  @override
  String get ebadat_monajatCopyFailed => 'Failed to copy';
}
