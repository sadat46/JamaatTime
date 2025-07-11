import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final NotificationService _notificationService = NotificationService();
  int _themeIndex = 0; // 0: White, 1: Light, 2: Dark
  String _madhab = 'hanafi';
  int _notificationSoundMode = 0; // 0: Custom, 1: System, 2: None

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final idx = await _settingsService.getThemeIndex();
    final madhab = await _settingsService.getMadhab();
    final soundMode = await _settingsService.getNotificationSoundMode();
    setState(() {
      _themeIndex = idx;
      _madhab = madhab;
      _notificationSoundMode = soundMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        color: const Color(0xFFE8F5E9), // light green background
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Card(
                    color: Theme.of(context).cardColor,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 0),
                          Text('Settings', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Theme'),
                              DropdownButton<int>(
                                value: _themeIndex,
                                items: const [
                                  DropdownMenuItem(value: 0, child: Text('White Theme')),
                                  DropdownMenuItem(value: 1, child: Text('Most Popular Light')),
                                  DropdownMenuItem(value: 2, child: Text('Most Popular Dark')),
                                  DropdownMenuItem(value: 3, child: Text('Green Theme')),
                                ],
                                onChanged: (val) async {
                                  if (val != null) {
                                    await _settingsService.setThemeIndex(val);
                                    setState(() => _themeIndex = val);
                                    themeIndexNotifier.value = val;
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Prayer Time Method'),
                              DropdownButton<String>(
                                value: _madhab,
                                items: const [
                                  DropdownMenuItem(value: 'hanafi', child: Text('Hanafi')),
                                  DropdownMenuItem(value: 'shafi', child: Text('Shafi')),
                                ],
                                onChanged: (val) async {
                                  if (val != null) {
                                    await _settingsService.setMadhab(val);
                                    setState(() => _madhab = val);
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Notification Sound'),
                              DropdownButton<int>(
                                value: _notificationSoundMode,
                                items: const [
                                  DropdownMenuItem(value: 0, child: Text('Custom Sound')),
                                  DropdownMenuItem(value: 1, child: Text('System Sound')),
                                  DropdownMenuItem(value: 2, child: Text('No Sound')),
                                ],
                                onChanged: (val) async {
                                  if (val != null) {
                                    await _settingsService.setNotificationSoundMode(val);
                                    setState(() => _notificationSoundMode = val);
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Copyright (c) 2025 sadat46\nAll rights reserved.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 