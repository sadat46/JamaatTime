import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/bookmark_service.dart';
import '../widgets/profile/profile_logged_in_content.dart';
import 'admin_tools_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _brandGreen = Color(0xFF388E3C);
  static const double _cardRadius = 18;

  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final ScrollController _authScrollController = ScrollController();

  String? _error;
  bool _loading = false;
  bool _showRegister = false;
  bool _isAdmin = false;
  bool _isSuperAdmin = false;
  bool _adminChecked = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String _version = '';
  String? _currentVersion;
  String? _buildNumber;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _loadVersion();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _authScrollController.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    try {
      final role = await _authService.getUserRole();
      if (!mounted) return;

      setState(() {
        _isSuperAdmin = role == UserRole.superadmin;
        _isAdmin = role == UserRole.admin || role == UserRole.superadmin;
        _adminChecked = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSuperAdmin = false;
        _isAdmin = false;
        _adminChecked = true;
      });
    }
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = 'v ${info.version} (${info.buildNumber})';
        _currentVersion = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (_) {
      // Keep version empty if package info is unavailable.
    }
  }

  Future<void> _checkForUpdate() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.github.com/repos/sadat46/jaamat-time-release/releases/latest',
        ),
        headers: const {'Accept': 'application/vnd.github+json'},
      );

      if (response.statusCode != 200) {
        throw Exception('GitHub responded with status ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final latestTag = (data['tag_name'] as String? ?? '').trim();
      final releaseUrl = data['html_url'] as String?;
      final assets = data['assets'] as List<dynamic>? ?? const [];

      if (latestTag.isEmpty) {
        throw Exception('Latest release tag not found');
      }

      final current = _currentVersion ?? '0.0.0';
      final comparison = _compareVersions(current, latestTag);

      if (comparison >= 0) {
        _showUpdateSnackBar('You are using the latest version');
        return;
      }

      String? downloadUrl;
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = asset['name'] as String?;
          final url = asset['browser_download_url'] as String?;
          if (name != null &&
              name.toLowerCase().endsWith('.apk') &&
              url != null) {
            downloadUrl = url;
            break;
          }
        }
      }

      downloadUrl ??= releaseUrl;
      if (downloadUrl == null) {
        _showUpdateSnackBar('Update available but no download link provided');
        return;
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Update Available'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current version: $current'),
                if (_buildNumber != null) Text('Build: $_buildNumber'),
                const SizedBox(height: 12),
                Text('Latest version: $latestTag'),
                if (data['body'] is String &&
                    (data['body'] as String).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    data['body'] as String,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Not Now'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _launchDownload(downloadUrl!);
                },
                child: const Text('Download'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      debugPrint('ProfileScreen: Update check failed - $error');
      _showUpdateSnackBar('Failed to check for updates');
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _launchDownload(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Unable to open $url');
      }
    } catch (error) {
      debugPrint('ProfileScreen: Launch failed - $error');
      _showUpdateSnackBar('Could not open download link');
    }
  }

  void _showUpdateSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  int _compareVersions(String current, String latest) {
    List<int> parse(String value) {
      var cleaned = value.trim();
      if (cleaned.toLowerCase().startsWith('v')) {
        cleaned = cleaned.substring(1);
      }
      cleaned = cleaned.split('+').first;
      cleaned = cleaned.split('-').first;

      final segments = cleaned.split('.');
      if (segments.isEmpty) {
        return [0];
      }

      return segments.map((segment) {
        final match = RegExp(r'\d+').firstMatch(segment);
        return match != null ? int.parse(match.group(0)!) : 0;
      }).toList();
    }

    final currentParts = parse(current);
    final latestParts = parse(latest);
    final maxLength = max(currentParts.length, latestParts.length);

    for (var i = 0; i < maxLength; i++) {
      final currentValue = i < currentParts.length ? currentParts[i] : 0;
      final latestValue = i < latestParts.length ? latestParts[i] : 0;
      if (currentValue != latestValue) {
        return currentValue.compareTo(latestValue);
      }
    }

    return 0;
  }

  String _roleLabel() {
    if (_isSuperAdmin) return 'Superadmin';
    if (_isAdmin) return 'Admin';
    return 'User';
  }

  Color _roleColor() {
    if (_isSuperAdmin) return Colors.red;
    if (_isAdmin) return Colors.orange;
    return const Color(0xFF2E7D32);
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
    if (!mounted) return;
    setState(() {
      _isAdmin = false;
      _isSuperAdmin = false;
      _adminChecked = true;
    });
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildLoggedOutActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 1.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: ListTile(
        minLeadingWidth: 0,
        horizontalTitleGap: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _brandGreen.withAlpha(26),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _brandGreen, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLoggedOutSettingsCard() {
    return _buildLoggedOutActionCard(
      icon: Icons.settings,
      title: 'Settings',
      subtitle: 'Prayer calculation, Hijri date, and reminder sound',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
      },
    );
  }

  Widget _buildAppInfoCard() {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _brandGreen.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: _brandGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'About This App',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _version.isEmpty
                  ? 'Installed version is currently unavailable.'
                  : 'Installed version: $_version',
              style: TextStyle(color: Colors.grey[700], height: 1.3),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isChecking ? null : _checkForUpdate,
                icon: _isChecking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.system_update_alt),
                label: Text(_isChecking ? 'Checking...' : 'Check for Updates'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Copyright (c) 2025 sadat46\nStatic Signal Coy, Savar\nAll rights reserved.',
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.grey[600],
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedInContent(User user) {
    if (!_adminChecked) {
      return const Center(child: CircularProgressIndicator());
    }

    return ProfileLoggedInContent(
      email: user.email ?? 'Logged in user',
      roleLabel: _roleLabel(),
      roleColor: _roleColor(),
      isAdmin: _isAdmin,
      isSuperAdmin: _isSuperAdmin,
      onLogout: () {
        _handleLogout();
      },
      onSettingsTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
      },
      onAdminToolsTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AdminToolsScreen(
              isAdmin: _isAdmin,
              isSuperAdmin: _isSuperAdmin,
              brandGreen: _brandGreen,
              cardRadius: _cardRadius,
            ),
          ),
        );
      },
      appInfoCard: _buildAppInfoCard(),
      brandGreen: _brandGreen,
      cardRadius: _cardRadius,
    );
  }

  Widget _buildAuthContent(BoxConstraints constraints) {
    return SingleChildScrollView(
      controller: _authScrollController,
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: max(0, constraints.maxHeight - 32),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionLabel('Account Access'),
            Card(
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_cardRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _showRegister ? 'Create Account' : 'Sign In',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Use your email to continue.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
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
                      const SizedBox(height: 10),
                      TextField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _confirmPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _confirmPasswordVisible =
                                    !_confirmPasswordVisible;
                              });
                            },
                          ),
                        ),
                        obscureText: !_confirmPasswordVisible,
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _loading
                          ? null
                          : () async {
                              setState(() {
                                _loading = true;
                                _error = null;
                                _adminChecked = false;
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

                                await BookmarkService().initialize();
                                await _checkAdmin();
                              } catch (e) {
                                setState(() {
                                  _error =
                                      "${_showRegister ? 'Registration' : 'Login'} failed: ${e.toString()}";
                                });
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _loading = false;
                                  });
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_showRegister ? 'Create Account' : 'Sign In'),
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
                            ? 'Already have an account? Sign in'
                            : 'Don\'t have an account? Create one',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildSectionLabel('Main Options'),
            _buildLoggedOutSettingsCard(),
            const SizedBox(height: 14),
            _buildSectionLabel('App'),
            _buildAppInfoCard(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: StreamBuilder<User?>(
        stream: _authService.userChanges,
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) {
            return LayoutBuilder(
              builder: (context, constraints) => _buildAuthContent(constraints),
            );
          }
          return _buildLoggedInContent(user);
        },
      ),
    );
  }
}
