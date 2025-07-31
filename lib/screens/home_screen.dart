import 'package:flutter/material.dart';
import '../widgets/home_header_card.dart';
import '../widgets/debug_actions_bar.dart';
import '../widgets/prayer_time_table.dart';
import '../services/home_controller.dart';
import '../core/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxContentWidth = constraints.maxWidth < 600
            ? constraints.maxWidth
            : 600.0;
        final horizontalPadding = constraints.maxWidth < 400 ? 8.0 : 16.0;
        
        return Scaffold(
          backgroundColor: const Color(0xFFE8F5E9),
          appBar: AppBar(
            title: const Text('Jamaat Time'),
            centerTitle: true,
            backgroundColor: const Color(0xFF388E3C),
            foregroundColor: Colors.white,
            elevation: 2,
            actions: [
              DebugActionsBar(
                onTestNotification: _controller.showTestNotification,
                onRescheduleNotifications: _controller.rescheduleNotifications,
                onCheckPendingNotifications: _controller.checkPendingNotifications,
                onScheduleTestJamaatNotification: _controller.scheduleTestJamaatNotification,
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeHeaderCard(
                      selectedCity: _controller.currentCity,
                      canttNames: AppConstants.canttNames,
                      selectedDate: _controller.selectedDate,
                      timeNotifier: _controller.timeNotifier,
                      countdownNotifier: _controller.countdownNotifier,
                      currentPlaceName: _controller.currentLocation,
                      isFetchingPlaceName: _controller.isLocationLoading,
                      isLoadingJamaat: _controller.isJamaatLoading,
                      jamaatError: _controller.jamaatErrorMessage,
                      onCityChanged: _controller.changeCity,
                      onLocationPressed: _controller.fetchUserLocation,
                      getCountdownText: _controller.getCountdownText,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Prayer Times',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_controller.isJamaatLoading)
                      const Center(child: CircularProgressIndicator()),
                    if (_controller.jamaatErrorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          _controller.jamaatErrorMessage!,
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ),
                    PrayerTimeTable(
                      prayerTimes: _controller.prayerTimesMap,
                      jamaatTimes: _controller.jamaatTimesData,
                      currentPrayerName: _controller.getCurrentPrayerName(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
