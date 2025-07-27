import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../main.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  int _prayerNotificationSoundMode = 0; // 0: Custom, 1: System, 2: None
  int _jamaatNotificationSoundMode = 0; // 0: Custom, 1: System, 2: None
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadVersion();
  }

  Future<void> _loadSettings() async {
    final idx = await _settingsService.getThemeIndex();
    final madhab = await _settingsService.getMadhab();
    final prayerSoundMode = await _settingsService.getPrayerNotificationSoundMode();
    final jamaatSoundMode = await _settingsService.getJamaatNotificationSoundMode();
    setState(() {
      _themeIndex = idx;
      _madhab = madhab;
      _prayerNotificationSoundMode = prayerSoundMode;
      _jamaatNotificationSoundMode = jamaatSoundMode;
    });
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = 'v ${info.version} ( ${info.buildNumber})';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9),
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: const Color(0xFF388E3C),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Center(
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
                              const Text('Prayer Notification'),
                              DropdownButton<int>(
                                value: _prayerNotificationSoundMode,
                                items: const [
                                  DropdownMenuItem(value: 0, child: Text('Custom Sound')),
                                  DropdownMenuItem(value: 1, child: Text('System Sound')),
                                  DropdownMenuItem(value: 2, child: Text('No Sound')),
                                ],
                                onChanged: (val) async {
                                  if (val != null) {
                                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                                    await _settingsService.setPrayerNotificationSoundMode(val);
                                    setState(() => _prayerNotificationSoundMode = val);
                                    
                                    // Handle notification sound mode change
                                    try {
                                      await _notificationService.handleNotificationSoundModeChange();
                                      
                                      // Show success message
                                      if (mounted) {
                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Prayer notification sound setting updated successfully!',
                                            ),
                                            backgroundColor: Colors.green,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      // Show error message
                                      if (mounted) {
                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error updating prayer notification settings: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Jamaat Notification'),
                              DropdownButton<int>(
                                value: _jamaatNotificationSoundMode,
                                items: const [
                                  DropdownMenuItem(value: 0, child: Text('Custom Sound')),
                                  DropdownMenuItem(value: 1, child: Text('System Sound')),
                                  DropdownMenuItem(value: 2, child: Text('No Sound')),
                                ],
                                onChanged: (val) async {
                                  if (val != null) {
                                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                                    await _settingsService.setJamaatNotificationSoundMode(val);
                                    setState(() => _jamaatNotificationSoundMode = val);
                                    
                                    // Handle notification sound mode change
                                    try {
                                      await _notificationService.handleNotificationSoundModeChange();
                                      
                                      // Show success message
                                      if (mounted) {
                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Jamaat notification sound setting updated successfully!',
                                            ),
                                            backgroundColor: Colors.green,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      // Show error message
                                      if (mounted) {
                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error updating jamaat notification settings: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    }
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
                  if (_version.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        'App Version:  $_version',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const Text(
                    'Copyright (c) 2025 sadat46\nStatic Signal Coy,Savar\nAll rights reserved.',
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