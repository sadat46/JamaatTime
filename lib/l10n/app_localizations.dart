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

  /// Home-screen widget label after the jamaat time has passed
  ///
  /// In en, this message translates to:
  /// **'Jamaat is Over'**
  String get widget_jamaatOver;

  /// Home-screen widget label prefix, e.g. 'Fajr Jamaat in 12m'
  ///
  /// In en, this message translates to:
  /// **'Jamaat in'**
  String get widget_jamaatInSuffix;

  /// Name of the Fajr prayer
  ///
  /// In en, this message translates to:
  /// **'Fajr'**
  String get prayer_fajr;

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
