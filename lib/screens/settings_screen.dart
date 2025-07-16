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
  int _notificationSoundMode = 0; // 0: Custom, 1: System, 2: None
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
    final soundMode = await _settingsService.getNotificationSoundMode();
    setState(() {
      _themeIndex = idx;
      _madhab = madhab;
      _notificationSoundMode = soundMode;
    });
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = 'v ${info.version} ( ${info.buildNumber})';
    });
  }

  String _getSoundModeText(int mode) {
    switch (mode) {
      case 0:
        return 'Custom Sound';
      case 1:
        return 'System Sound';
      case 2:
        return 'No Sound';
      default:
        return 'Unknown';
    }
  }

  String _getChannelId(int mode) {
    switch (mode) {
      case 0:
        return 'Custom Sound Channel';
      case 1:
        return 'System Sound Channel';
      case 2:
        return 'No Sound Channel';
      default:
        return 'Unknown Channel';
    }
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
                                    
                                    // Handle notification sound mode change
                                    try {
                                      await _notificationService.handleNotificationSoundModeChange();
                                      
                                      // Show success message
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Notification sound setting updated successfully!',
                                            ),
                                            backgroundColor: Colors.green,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      // Show error message
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error updating notification settings: $e',
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
                              const Text('Test Notifications'),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  ElevatedButton(
                                    onPressed: () async {
                                      try {
                                        await _notificationService.testNotification();
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Test notification sent! (Sound Mode: ${_getSoundModeText(_notificationSoundMode)})',
                                              ),
                                              backgroundColor: Colors.green,
                                              duration: const Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red,
                                              duration: const Duration(seconds: 4),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: const Text('Test Now'),
                                  ),
                                  const SizedBox(height: 4),
                                  ElevatedButton(
                                    onPressed: () async {
                                      try {
                                        await _notificationService.recreateNotificationChannel();
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Notification channel recreated successfully!'),
                                              backgroundColor: Colors.blue,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Channel recreation error: $e'),
                                              backgroundColor: Colors.red,
                                              duration: const Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                    child: const Text('Recreate Channel', style: TextStyle(fontSize: 10)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Current: ${_getSoundModeText(_notificationSoundMode)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    'Channel: ${_getChannelId(_notificationSoundMode)}',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
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