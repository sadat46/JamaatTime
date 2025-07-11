import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'services/settings_service.dart';
import 'themes/white_theme.dart';
import 'themes/light_theme.dart';
import 'themes/dark_theme.dart';
import 'themes/green_theme.dart';

final ValueNotifier<int> themeIndexNotifier = ValueNotifier(0); // 0: White, 1: Light, 2: Dark, 3: Green

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase
    if (kIsWeb) {
      // For web platform, use a default Firebase configuration or skip initialization
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "REDACTED_FIREBASE_API_KEY",
          authDomain: "jaamattime.firebaseapp.com",
          projectId: "jaamattime",
          storageBucket: "jaamattime.firebasestorage.app",
          messagingSenderId: "148161891333",
          appId: "1:148161891333:web:your-web-app-id",
        ),
      );
    } else {
      // For mobile platforms, use the generated options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // Handle initialization errors gracefully
    debugPrint("Firebase initialization error: $e");
    // Continue with the app even if Firebase fails to initialize
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
        final themes = [whiteTheme, popularLightTheme, popularDarkTheme, greenTheme];
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
    HomeScreen(),
    SettingsScreen(),
    ProfileScreen(),
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
