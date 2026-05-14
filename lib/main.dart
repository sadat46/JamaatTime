import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/ebadat/ebadat_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/profile_screen.dart';
import 'package:home_widget/home_widget.dart';
import 'services/notifications/notification_service.dart';
import 'services/notifications/fcm/fcm_service.dart';
import 'services/bookmark_service.dart';
import 'services/widget_service.dart';
import 'services/settings_service.dart';
import 'core/app_locale_controller.dart';
import 'core/app_theme_tokens.dart';
import 'core/firebase_bootstrap.dart';
import 'core/timezone_bootstrap.dart';
import 'themes/green_theme.dart';

// Global navigator key shared with FcmService so push taps can route from
// outside the widget tree.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  unawaited(firebaseReady);

  // Register the widget interaction callback. Native boundary alarms also route
  // through HomeWidget's background receiver.
  HomeWidget.registerInteractivityCallback(backgroundCallback);

  AppLocaleController.bootstrapWithFallback();
  unawaited(AppLocaleController.instance.loadPersisted());

  runApp(const MyApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_runPostFirstFrameBootstrap());
  });
}

Future<void> _runPostFirstFrameBootstrap() async {
  ensureTimeZonesInitialized();

  try {
    if (await firebaseReady) {
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        BookmarkService().initialize();
      });
    }
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
    if (await firebaseReady) {
      await FcmService().init(
        navigatorKey: appNavigatorKey,
        locale: AppLocaleController.instance.current.languageCode,
      );
    }
  } catch (_) {
    // Continue startup even if FCM fails; local jamaat reminders still work.
  }
}

ThemeData _themeFor(Locale locale) {
  final fontFamily = locale.languageCode == 'bn' ? 'NotoSansBengali' : 'Inter';
  return greenTheme.copyWith(
    textTheme: greenTheme.textTheme.apply(fontFamily: fontFamily),
  );
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
  final Set<int> _builtTabIndexes = <int>{0};

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _builtTabIndexes.add(index);
    });
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return HomeScreen(isActive: _selectedIndex == 0);
      case 1:
        return const EbadatScreen();
      case 2:
        return const CalendarScreen();
      case 3:
        return const ProfileScreen();
      default:
        throw RangeError.index(index, const [0, 1, 2, 3], 'index');
    }
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
    return Scaffold(
      body: Stack(
        children: [
          for (var index = 0; index < 4; index++)
            if (_builtTabIndexes.contains(index))
              KeyedSubtree(
                key: ValueKey<String>('main-tab-$index'),
                child: TickerMode(
                  enabled: _selectedIndex == index,
                  child: Offstage(
                    offstage: _selectedIndex != index,
                    child: _buildTab(index),
                  ),
                ),
              ),
        ],
      ),
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
