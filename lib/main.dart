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
import 'services/bookmark_service.dart';
import 'services/widget_service.dart';
import 'services/settings_service.dart';
import 'core/app_locale_controller.dart';
import 'core/constants.dart';
import 'themes/green_theme.dart';

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

    // Initialize BookmarkService and listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      BookmarkService().initialize();
    });
  } catch (e) {
    // Handle initialization errors gracefully
    // Continue with the app even if Firebase fails to initialize
  }

  // One-time migration for default notification sounds.
  try {
    await SettingsService().migrateNotificationSoundDefaultsToCustom2();
  } catch (e) {
    // Continue with the app even if migration fails
  }

  // Initialize notification service
  try {
    final notificationService = NotificationService();
    await notificationService.initialize(null);
  } catch (e) {
    // Continue with the app even if notification service fails to initialize
  }

  // Register home widget background callback for refresh button
  HomeWidget.registerInteractivityCallback(backgroundCallback);

  // Load the persisted locale before the first frame so the UI renders in
  // the correct language with no flicker (D15).
  await AppLocaleController.bootstrap();

  runApp(const MyApp());
}

ThemeData _themeFor(Locale locale) {
  final baseTextTheme = greenTheme.textTheme;
  final localizedTextTheme = locale.languageCode == 'bn'
      ? GoogleFonts.hindSiliguriTextTheme(baseTextTheme)
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

  static const List<Widget> _screens = <Widget>[
    HomeScreen(), // index: 0
    EbadatScreen(), // index: 1
    CalendarScreen(), // index: 2
    ProfileScreen(), // index: 3
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppConstants.brandGreen,
        unselectedItemColor: Colors.black54,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.mosque), label: 'Ebadat'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
