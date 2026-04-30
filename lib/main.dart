import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/ebadat/ebadat_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/profile_screen.dart';
import 'package:home_widget/home_widget.dart';
import 'services/notification_service.dart';
import 'services/notifications/fcm_service.dart';
import 'services/bookmark_service.dart';
import 'services/widget_service.dart';
import 'services/settings_service.dart';
import 'core/app_locale_controller.dart';
import 'core/app_theme_tokens.dart';
import 'themes/green_theme.dart';

// Global navigator key — shared with FcmService so push taps can route from
// outside the widget tree.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone data once at app startup (faster than in each screen)
  tzdata.initializeTimeZones();
  // Removed timezone forcing to support global usage - device local time will be used

  try {
    // Initialize Firebase for all platforms
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Handle initialization errors gracefully
    // Continue with the app even if Firebase fails to initialize
  }

  // Register the widget interaction callback. Native boundary alarms also route
  // through HomeWidget's background receiver.
  HomeWidget.registerInteractivityCallback(backgroundCallback);

  // Load the persisted locale before the first frame so the UI renders in
  // the correct language with no flicker (D15).
  await AppLocaleController.bootstrap();

  runApp(const MyApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_runPostFirstFrameBootstrap());
  });
}

Future<void> _runPostFirstFrameBootstrap() async {
  unawaited(_preloadActiveLocaleFonts());

  try {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      BookmarkService().initialize();
    });
  } catch (_) {
    // Continue without bookmark warmup if Firebase auth is unavailable.
  }

  try {
    await SettingsService().migrateNotificationSoundDefaultsToCustom2();
  } catch (_) {
    // Continue with the app even if migration fails.
  }

  try {
    await NotificationService().initialize(null);
  } catch (_) {
    // Continue with the app even if notification service fails to initialize.
  }

  try {
    await FcmService().init(
      navigatorKey: appNavigatorKey,
      locale: AppLocaleController.instance.current.languageCode,
    );
  } catch (_) {
    // Continue startup even if FCM fails; local jamaat reminders still work.
  }
}

Future<void> _preloadActiveLocaleFonts() async {
  try {
    final baseTextTheme = greenTheme.textTheme;
    if (AppLocaleController.instance.current.languageCode == 'bn') {
      GoogleFonts.notoSansBengaliTextTheme(baseTextTheme);
    } else {
      GoogleFonts.interTextTheme(baseTextTheme);
    }
    await GoogleFonts.pendingFonts();
  } catch (_) {
    // Keep startup resilient if font preloading fails.
  }
}

ThemeData _themeFor(Locale locale) {
  final baseTextTheme = greenTheme.textTheme;
  final localizedTextTheme = locale.languageCode == 'bn'
      ? GoogleFonts.notoSansBengaliTextTheme(baseTextTheme)
      : GoogleFonts.interTextTheme(baseTextTheme);
  return greenTheme.copyWith(textTheme: localizedTextTheme);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLocaleController.instance.notifier,
      builder: (context, locale, _) {
        return MaterialApp(
          title: 'Jamaat Time',
          navigatorKey: appNavigatorKey,
          theme: _themeFor(locale),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MainScaffold(),
        );
      },
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _navIcon(int index, IconData icon) {
    final isSelected = _selectedIndex == index;
    return Container(
      width: 46,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Icon(
        icon,
        size: 24,
        color: isSelected ? AppColors.primaryGreen : AppColors.navInactive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final screens = <Widget>[
      HomeScreen(isActive: _selectedIndex == 0), // index: 0
      const EbadatScreen(), // index: 1
      const CalendarScreen(), // index: 2
      const ProfileScreen(), // index: 3
    ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          border: Border(top: BorderSide(color: AppColors.borderLight)),
          boxShadow: AppShadows.navBar,
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.cardBackground,
          elevation: 0,
          selectedItemColor: AppColors.primaryGreen,
          unselectedItemColor: AppColors.navInactive,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: [
            BottomNavigationBarItem(
              icon: _navIcon(0, Icons.home),
              label: strings.nav_home,
            ),
            BottomNavigationBarItem(
              icon: _navIcon(1, Icons.mosque),
              label: strings.nav_ebadat,
            ),
            BottomNavigationBarItem(
              icon: _navIcon(2, Icons.calendar_month),
              label: strings.nav_calendar,
            ),
            BottomNavigationBarItem(
              icon: _navIcon(3, Icons.person),
              label: strings.nav_profile,
            ),
          ],
        ),
      ),
    );
  }
}
