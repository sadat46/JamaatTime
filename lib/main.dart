import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/ebadat/ebadat_screen.dart';
import 'screens/profile_screen.dart';
import 'services/settings_service.dart';
import 'services/notification_service.dart';
import 'services/bookmark_service.dart';
import 'themes/white_theme.dart';
import 'themes/light_theme.dart';
import 'themes/dark_theme.dart';
import 'themes/green_theme.dart';
import 'core/constants.dart';

final ValueNotifier<int> themeIndexNotifier = ValueNotifier(
  0,
); // 0: White, 1: Light, 2: Dark, 3: Green

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone data once at app startup (faster than in each screen)
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation(AppConstants.defaultTimeZone));

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

  // Initialize notification service
  try {
    final notificationService = NotificationService();
    await notificationService.initialize(null);
  } catch (e) {
    // Continue with the app even if notification service fails to initialize
  }

  final settingsService = SettingsService();
  final idx = await settingsService.getThemeIndex();
  themeIndexNotifier.value = idx;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: themeIndexNotifier,
      builder: (context, idx, _) {
        final themes = [
          whiteTheme,
          popularLightTheme,
          popularDarkTheme,
          greenTheme,
        ];
        return MaterialApp(
          title: 'Jamaat Time',
          theme: themes[idx],
          darkTheme: popularDarkTheme,
          themeMode: idx == 2 ? ThemeMode.dark : ThemeMode.light,
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
    HomeScreen(),      // index: 0
    EbadatScreen(),    // index: 1 - NEW
    ProfileScreen(),   // index: 2
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mosque),
            label: 'ইবাদত',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
