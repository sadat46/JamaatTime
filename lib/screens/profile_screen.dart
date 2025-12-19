import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../services/bookmark_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'user_management_screen.dart';
import 'admin_jamaat_panel.dart';
import 'notification_monitor_screen.dart';
import 'bookmarks_screen.dart';
import '../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final SettingsService _settingsService = SettingsService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  String? _error;
  bool _loading = false;
  bool _showRegister = false;
  bool _isAdmin = false;
  bool _isSuperAdmin = false;
  bool _adminChecked = false; // <-- Add this flag
  bool _passwordVisible = false; // For password field
  bool _confirmPasswordVisible = false; // For confirm password field

  // Settings state variables
  int _themeIndex = 0; // 0: White, 1: Light, 2: Dark, 3: Green
  String _madhab = 'hanafi';
  int _prayerNotificationSoundMode = 0; // 0: Custom, 1: System, 2: None
  int _jamaatNotificationSoundMode = 0; // 0: Custom, 1: System, 2: None
  String _version = '';

  @override
  void initState() {
    super.initState();
    _adminChecked = false; // Reset before checking
    // Check admin status
    _checkAdmin();
    // Load settings
    _loadSettings();
    _loadVersion();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    // Single role check instead of two separate Firestore reads
    final role = await _authService.getUserRole();

    setState(() {
      _isSuperAdmin = role == UserRole.superadmin;
      _isAdmin = role == UserRole.admin || role == UserRole.superadmin;
      _adminChecked = true; // Set to true after check
    });
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
      appBar: AppBar(
         title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: const Color(0xFF388E3C),
        foregroundColor: Colors.white,
        elevation: 2,),
      body: StreamBuilder<User?>(
        stream: _authService.userChanges,
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) {
            // Not logged in
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _showRegister ? 'Register' : 'Login',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _passwordVisible = !_passwordVisible;
                          });
                        },
                      ),
                    ),
                    obscureText: !_passwordVisible,
                  ),
                  if (_showRegister) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _confirmPasswordVisible = !_confirmPasswordVisible;
                            });
                          },
                        ),
                      ),
                      obscureText: !_confirmPasswordVisible,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            setState(() {
                              _loading = true;
                              _error = null;
                              _adminChecked = false; // Reset before checking
                            });
                            try {
                              if (_showRegister) {
                                if (_passwordController.text !=
                                    _confirmPasswordController.text) {
                                  setState(() {
                                    _error = 'Passwords do not match';
                                    _loading = false;
                                  });
                                  return;
                                }
                                await _authService.register(
                                  _emailController.text.trim(),
                                  _passwordController.text.trim(),
                                );
                              } else {
                                await _authService.signIn(
                                  _emailController.text.trim(),
                                  _passwordController.text.trim(),
                                );
                              }

                              // Initialize BookmarkService after successful login/registration
                              await BookmarkService().initialize();

                              await _checkAdmin();
                            } catch (e) {
                              setState(() {
                                _error =
                                    "${_showRegister ? 'Registration' : 'Login'} failed: ${e.toString()}";
                              });
                            } finally {
                              setState(() {
                                _loading = false;
                              });
                            }
                          },
                    child: _loading
                        ? const CircularProgressIndicator()
                        : Text(_showRegister ? 'Register' : 'Login'),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _showRegister = !_showRegister;
                              _error = null;
                            });
                          },
                    child: Text(
                      _showRegister
                          ? 'Already have an account? Login'
                          : 'Don\'t have an account? Register',
                    ),
                  ),
                ],
              ),
            );
          } else {
            // Logged in
            if (!_adminChecked) {
              return const Center(child: CircularProgressIndicator());
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Logged in as: ${_isSuperAdmin ? 'Superadmin' : _isAdmin ? 'Admin' : 'User'}',
                          ),
                          if (_isSuperAdmin || _isAdmin)
                      Text(
                              'Role: ${_isSuperAdmin ? 'Superadmin' : 'Admin'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _isSuperAdmin ? Colors.red : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      Column(
                        children: [
                      ElevatedButton(
                        onPressed: () async {
                          await _authService.signOut();
                          setState(() {
                            _isAdmin = false;
                            _isSuperAdmin = false;
                          });
                        },
                        child: const Text('Logout'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Settings Card (Collapsible)
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      leading: const Icon(
                        Icons.settings,
                        color: Color(0xFF388E3C),
                        size: 24,
                      ),
                      title: Text(
                        'সেটিংস',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF388E3C),
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                          // Theme Setting
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

                          // Madhab Setting
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

                          // Prayer Notification Setting
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
                                          const SnackBar(
                                            content: Text(
                                              'Prayer notification sound setting updated successfully!',
                                            ),
                                            backgroundColor: Colors.green,
                                            duration: Duration(seconds: 2),
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

                          // Jamaat Notification Setting
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
                                          const SnackBar(
                                            content: Text(
                                              'Jamaat notification sound setting updated successfully!',
                                            ),
                                            backgroundColor: Colors.green,
                                            duration: Duration(seconds: 2),
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // My Bookmarks Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.bookmark,
                        color: Color(0xFF388E3C),
                        size: 28,
                      ),
                      title: const Text(
                        'আমার বুকমার্ক',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: const Text('সংরক্ষিত আয়াত ও দোয়া'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BookmarksScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Superadmin User Management Section
                  if (_isSuperAdmin) ...[
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.admin_panel_settings,
                                  color: Colors.red,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Superadmin Controls',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const UserManagementScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.people),
                              label: const Text('Manage Users'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Manage user roles, view statistics, and control access',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Admin Jamaat Management Section
                  if (_isAdmin) ...[
                    // Admin Controls Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.admin_panel_settings,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Admin Controls',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => const AdminJamaatPanel(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.file_upload),
                                    label: const Text('Edit/Import Data'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'CSV Import/Export, Bulk Operations, Yearly Data',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Notification Motor Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.notifications_active,
                                  color: Colors.blue,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Notification Motor',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => const NotificationMonitorScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.monitor),
                                    label: const Text('Monitor Notification'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Monitor and manage notification settings and status',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Version and Copyright Info
                  const SizedBox(height: 32),
                  if (_version.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        'App Version:  $_version',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
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
                  const SizedBox(height: 100),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}


