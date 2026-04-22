import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
  ];

  /// Bottom navigation label for the Home tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get nav_home;

  /// Bottom navigation label for the Ebadat tab
  ///
  /// In en, this message translates to:
  /// **'Ebadat'**
  String get nav_ebadat;

  /// Bottom navigation label for the Calendar tab
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get nav_calendar;

  /// Bottom navigation label for the Profile tab
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get nav_profile;

  /// Section header for the language picker in Settings
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_languageSection;

  /// Subtitle under the Language section header
  ///
  /// In en, this message translates to:
  /// **'Choose the app display language.'**
  String get settings_languageSubtitle;

  /// Label above the language dropdown field
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settings_languageLabel;

  /// Dropdown item label for Bengali
  ///
  /// In en, this message translates to:
  /// **'বাংলা'**
  String get settings_languageBangla;

  /// Dropdown item label for English
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settings_languageEnglish;

  /// Home-screen widget label when no jamaat is scheduled
  ///
  /// In en, this message translates to:
  /// **'Jamaat N/A'**
  String get widget_jamaatNA;

  /// Home-screen widget label after jamaat window has passed
  ///
  /// In en, this message translates to:
  /// **'Jamaat ended'**
  String get widget_jamaatOver;

  /// Home-screen widget label while jamaat is ongoing
  ///
  /// In en, this message translates to:
  /// **'Jamaat ongoing'**
  String get widget_jamaatOngoing;

  /// Home-screen widget label prefix, e.g. 'Fajr Jamaat in 12m'
  ///
  /// In en, this message translates to:
  /// **'Jamaat in'**
  String get widget_jamaatInSuffix;

  /// Widget countdown label during Sunrise period
  ///
  /// In en, this message translates to:
  /// **'Coming Dhuhr'**
  String get widget_comingDhuhr;

  /// Widget countdown label for normal prayer periods
  ///
  /// In en, this message translates to:
  /// **'Prayer ends in'**
  String get widget_prayerEndsIn;

  /// Widget countdown label during Sunrise using next prayer name
  ///
  /// In en, this message translates to:
  /// **'{prayer} in'**
  String widget_nextPrayerIn(String prayer);

  /// Widget sunrise line showing next prayer jamaat time
  ///
  /// In en, this message translates to:
  /// **'{prayer} Jamaat at {time}'**
  String widget_nextPrayerJamaatAt(String prayer, String time);

  /// Widget countdown label for active prayer period
  ///
  /// In en, this message translates to:
  /// **'{prayer} Time Remaining'**
  String widget_timeRemaining(String prayer);

  /// Name of the Fajr prayer
  ///
  /// In en, this message translates to:
  /// **'Fajr'**
  String get prayer_fajr;

  /// Name of the Sunrise period
  ///
  /// In en, this message translates to:
  /// **'Sunrise'**
  String get prayer_sunrise;

  /// Name of the Dhuhr prayer
  ///
  /// In en, this message translates to:
  /// **'Dhuhr'**
  String get prayer_dhuhr;

  /// Name of the Asr prayer
  ///
  /// In en, this message translates to:
  /// **'Asr'**
  String get prayer_asr;

  /// Name of the Maghrib prayer
  ///
  /// In en, this message translates to:
  /// **'Maghrib'**
  String get prayer_maghrib;

  /// Name of the Isha prayer
  ///
  /// In en, this message translates to:
  /// **'Isha'**
  String get prayer_isha;

  /// Prayer notification title
  ///
  /// In en, this message translates to:
  /// **'{prayer} Prayer'**
  String notification_prayerTitle(String prayer);

  /// Prayer notification body
  ///
  /// In en, this message translates to:
  /// **'{prayer} time remaining 20 minutes.'**
  String notification_prayerBody(String prayer);

  /// Jamaat notification title
  ///
  /// In en, this message translates to:
  /// **'{prayer} Jamaat'**
  String notification_jamaatTitle(String prayer);

  /// Jamaat notification body
  ///
  /// In en, this message translates to:
  /// **'{prayer} Jamaat is in 10 minutes.'**
  String notification_jamaatBody(String prayer);

  /// Tooltip on monajat detail copy icon button
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get ebadat_monajatCopyTooltip;

  /// Section label for pronunciation in monajat detail
  ///
  /// In en, this message translates to:
  /// **'Pronunciation'**
  String get ebadat_monajatPronunciationLabel;

  /// Section label for meaning in monajat detail
  ///
  /// In en, this message translates to:
  /// **'Meaning'**
  String get ebadat_monajatMeaningLabel;

  /// Section label for context/fadilat in monajat detail
  ///
  /// In en, this message translates to:
  /// **'Context & Benefit'**
  String get ebadat_monajatContextLabel;

  /// Short label for context line in copied monajat text
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get ebadat_monajatContextShortLabel;

  /// Primary button label in monajat detail for copy
  ///
  /// In en, this message translates to:
  /// **'Copy Full Dua'**
  String get ebadat_monajatCopyButton;

  /// Snackbar text when monajat copy succeeds
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get ebadat_monajatCopySuccess;

  /// Snackbar text when monajat copy fails
  ///
  /// In en, this message translates to:
  /// **'Failed to copy'**
  String get ebadat_monajatCopyFailed;

  /// Label for transliteration section in ebadat cards
  ///
  /// In en, this message translates to:
  /// **'Transliteration'**
  String get ebadat_transliterationLabel;

  /// Label for meaning section in ebadat cards
  ///
  /// In en, this message translates to:
  /// **'Meaning'**
  String get ebadat_meaningLabel;

  /// Default expandable references section title
  ///
  /// In en, this message translates to:
  /// **'References'**
  String get ebadat_referencesTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['bn', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
