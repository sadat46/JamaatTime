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
  String get widget_jamaatOver => 'Jamaat ended';

  @override
  String get widget_jamaatOngoing => 'Jamaat ongoing';

  @override
  String get widget_jamaatInSuffix => 'Jamaat in';

  @override
  String get widget_comingDhuhr => 'Coming Dhuhr';

  @override
  String get widget_prayerEndsIn => 'Prayer ends in';

  @override
  String widget_nextPrayerIn(String prayer) {
    return '$prayer in';
  }

  @override
  String widget_nextPrayerJamaatAt(String prayer, String time) {
    return '$prayer Jamaat at $time';
  }

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

  @override
  String get ebadat_transliterationLabel => 'Transliteration';

  @override
  String get ebadat_meaningLabel => 'Meaning';

  @override
  String get ebadat_referencesTitle => 'References';

  @override
  String get familySafetyTitle => 'Family Safety';

  @override
  String get familySafetySubtitle =>
      'Help protect your family from harmful and distracting online content.';

  @override
  String get familySafetyIntro =>
      'Optional on-device tools for family-friendly browsing habits and safer setup guidance.';

  @override
  String get websiteProtectionTitle => 'Website Protection';

  @override
  String get websiteProtectionSubtitle =>
      'Block selected harmful website categories when protection is enabled.';

  @override
  String get websiteProtectionPlaceholder =>
      'Website Protection setup will be added in a later phase. No VPN or sensitive permission is active in this release.';

  @override
  String get websiteProtectionEnableCta => 'Enable Website Protection';

  @override
  String get websiteProtectionVpnDisclosureTitle =>
      'Enable Website Protection?';

  @override
  String get websiteProtectionVpnDisclosureBody =>
      'Website Protection helps block harmful website categories (such as adult\ncontent, gambling, and proxy-bypass sites) for everyone using this device.\n\nTo do this, the app uses Android\'s VPN system locally on your device to\ninspect website addresses (domain names) and block selected categories.\n\nWhat this feature does NOT do:\n• It does not read messages, passwords, or payment details.\n• It does not inspect the contents of secure (HTTPS) pages.\n• It does not install any certificates.\n• It does not upload your browsing to any server.\n\nActivity summaries (counts only) are stored on your device and you can\nclear them at any time. You can disable Website Protection from this\nscreen whenever you want.';

  @override
  String get digitalWellbeingTitle => 'Digital Wellbeing';

  @override
  String get digitalWellbeingSubtitle =>
      'Review focus-friendly options without changing existing Focus Guard behavior.';

  @override
  String get digitalWellbeingPlaceholder =>
      'Digital Wellbeing status will connect to the existing Focus Guard feature in a later phase.';

  @override
  String get parentControlTitle => 'Parent Control';

  @override
  String get parentControlSubtitle =>
      'Use a local PIN to guard Family Safety settings.';

  @override
  String get parentControlSetPin => 'Set PIN';

  @override
  String get parentControlChangePin => 'Change PIN';

  @override
  String get parentControlForgotPinWarning =>
      'This will reset your PIN and disable Website Protection. To reset, type the word DISABLE.';

  @override
  String get parentControlPlaceholder =>
      'PIN setup will be added in a later phase. It will guard only Family Safety settings.';

  @override
  String get safeSearchSetupTitle => 'Safe Search Setup';

  @override
  String get safeSearchSetupSubtitle =>
      'Guidance for SafeSearch, Restricted Mode, and family-filtered DNS.';

  @override
  String get safeSearchSetupPlaceholder =>
      'Safe Search and Private DNS guidance will be added in the next phase.';

  @override
  String get activitySummaryTitle => 'Activity Summary';

  @override
  String get activitySummarySubtitle =>
      'View local counts for blocked categories without storing browsing history.';

  @override
  String get activitySummaryPlaceholder =>
      'Activity Summary will show local counts only after Website Protection exists.';

  @override
  String get privacyExplanationTitle => 'Privacy';

  @override
  String get privacyExplanationSubtitle =>
      'Understand what Family Safety does locally on this device.';

  @override
  String get familySafetyPrivacyExplanation =>
      'Family Safety is optional and off by default. This phase adds only guidance and placeholder screens. It does not add a VPN, Accessibility changes, overlays, DNS upload, HTTPS interception, or new permissions.';

  @override
  String get familySafetyNotNowCta => 'Not now';

  @override
  String get familySafetyContinueGrantPermissionCta =>
      'Continue and grant permission';
}
