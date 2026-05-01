import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/focus_guard_settings.dart';
import '../services/focus_guard_service.dart';
import '../widgets/focus_guard/munajat_disable_dialog.dart';

class FocusGuardScreen extends StatefulWidget {
  const FocusGuardScreen({super.key});

  @override
  State<FocusGuardScreen> createState() => _FocusGuardScreenState();
}

class _FocusGuardScreenState extends State<FocusGuardScreen>
    with WidgetsBindingObserver {
  final FocusGuardService _service = FocusGuardService();

  FocusGuardSettings _settings = const FocusGuardSettings();
  bool _accessibilityEnabled = false;
  bool _accessibilityDisclosureAccepted = false;
  bool _loading = true;

  static const List<int> _tempAllowOptions = [5, 10, 15];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissions();
    }
  }

  Future<void> _bootstrap() async {
    final settings = await _service.loadSettings();
    final perms = await _service.getPermissionStatus();
    final disclosureAccepted = await _service
        .hasAccessibilityDisclosureConsent();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _accessibilityEnabled = perms['accessibility'] ?? false;
      _accessibilityDisclosureAccepted = disclosureAccepted;
      _loading = false;
    });
  }

  Future<void> _refreshPermissions() async {
    final perms = await _service.getPermissionStatus();
    if (!mounted) return;
    setState(() {
      _accessibilityEnabled = perms['accessibility'] ?? false;
    });
  }

  Future<void> _save(FocusGuardSettings next) async {
    setState(() => _settings = next);
    await _service.saveSettings(next);
  }

  Future<void> _handleMasterToggle(bool value) async {
    if (value) {
      await _save(_settings.copyWith(enabled: true));
      return;
    }
    final munajat = _service.getRandomMunajat();
    if (!mounted) return;
    await MunajatDisableDialog.show(
      context,
      monajat: munajat,
      onConfirmDisable: () {
        _save(_settings.copyWith(enabled: false));
      },
    );
  }

  Future<void> _handleYouTubeToggle(bool value) async {
    final next = Map<String, bool>.from(_settings.blockedApps);
    next['youtube'] = value;
    await _save(_settings.copyWith(blockedApps: next));
  }

  Future<void> _handleTempAllowChange(int minutes) async {
    await _save(_settings.copyWith(tempAllowMinutes: minutes));
  }

  Future<void> _handleQuickAllowToggle(bool value) async {
    await _save(_settings.copyWith(quickAllowEnabled: value));
  }

  Future<void> _handleAccessibilitySetup() async {
    if (!_accessibilityDisclosureAccepted) {
      final accepted = await _showAccessibilityDisclosureDialog();
      if (accepted != true) return;
      await _service.setAccessibilityDisclosureConsent(true);
      if (!mounted) return;
      setState(() => _accessibilityDisclosureAccepted = true);
    }
    await _service.openAccessibilitySettings();
  }

  Future<bool?> _showAccessibilityDisclosureDialog() {
    var checked = false;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Accessibility Disclosure'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Focus Guard uses Android Accessibility to inspect the '
                      'current YouTube screen only enough to detect Shorts or '
                      'Reels. Accessibility data is processed on this device '
                      'and is not sent from the app.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'When Shorts is detected, Focus Guard shows a blocking '
                      'overlay. It will use the Back action only after you tap '
                      'Go Back in that overlay.',
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: checked,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'I understand and agree to enable Accessibility for '
                        'Focus Guard.',
                      ),
                      onChanged: (value) {
                        setDialogState(() => checked = value ?? false);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: checked
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Guard'),
        centerTitle: true,
        backgroundColor: AppConstants.brandGreen,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  'Block short-video feeds (YouTube Shorts) to stay focused. '
                  'No data leaves your device.',
                  style: TextStyle(color: Colors.grey[700], height: 1.35),
                ),
                const SizedBox(height: 16),
                _permissionCard(
                  icon: Icons.accessibility_new,
                  title: 'Accessibility Service',
                  subtitle: 'Required to detect when YouTube Shorts is opened.',
                  granted: _accessibilityEnabled,
                  onSetup: _handleAccessibilitySetup,
                ),
                const SizedBox(height: 18),
                _masterToggleCard(),
                const SizedBox(height: 14),
                _appsCard(),
                const SizedBox(height: 14),
                _tempAllowCard(),
              ],
            ),
    );
  }

  Widget _permissionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
    required Future<void> Function() onSetup,
  }) {
    final statusColor = granted ? Colors.green : Colors.red;
    final statusIcon = granted ? Icons.check_circle : Icons.cancel;
    return Card(
      elevation: 1.2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppConstants.brandGreen.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppConstants.brandGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(statusIcon, color: statusColor, size: 20),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () async {
                        await onSetup();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppConstants.brandGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(granted ? 'Review' : 'Setup'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _masterToggleCard() {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile(
        value: _settings.enabled,
        onChanged: _handleMasterToggle,
        activeThumbColor: AppConstants.brandGreen,
        title: const Text(
          'Focus Guard',
          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          _settings.enabled
              ? 'Active — short-video feeds will be blocked.'
              : 'Off — no blocking is applied.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _appsCard() {
    final youtubeOn = _settings.blockedApps['youtube'] ?? true;
    return Card(
      elevation: 1.2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          children: [
            SwitchListTile(
              value: youtubeOn,
              onChanged: _settings.enabled
                  ? (v) => _handleYouTubeToggle(v)
                  : null,
              activeThumbColor: AppConstants.brandGreen,
              secondary: const Icon(Icons.smart_display, color: Colors.red),
              title: const Text(
                'YouTube Shorts',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Block Shorts feed',
                style: TextStyle(fontSize: 11.5),
              ),
            ),
            _comingSoonTile(
              icon: Icons.photo_camera,
              color: Colors.pinkAccent,
              title: 'Instagram Reels',
            ),
            _comingSoonTile(
              icon: Icons.facebook,
              color: Colors.blue,
              title: 'Facebook Reels',
            ),
            _comingSoonTile(
              icon: Icons.music_note,
              color: Colors.black87,
              title: 'TikTok',
            ),
          ],
        ),
      ),
    );
  }

  Widget _comingSoonTile({
    required IconData icon,
    required Color color,
    required String title,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Coming soon',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      enabled: false,
    );
  }

  Widget _tempAllowCard() {
    final quickAllowOn = _settings.quickAllowEnabled;
    final subtitle = quickAllowOn
        ? 'Overlay will show "Allow ${_settings.tempAllowMinutes} min".'
        : 'Overlay will only show "Go Back".';
    return Card(
      elevation: 1.2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              value: quickAllowOn,
              onChanged: _settings.enabled
                  ? (v) => _handleQuickAllowToggle(v)
                  : null,
              activeThumbColor: AppConstants.brandGreen,
              title: const Text(
                'Allow quick bypass',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Opacity(
                opacity: quickAllowOn ? 1.0 : 0.45,
                child: SegmentedButton<int>(
                  segments: _tempAllowOptions
                      .map(
                        (m) =>
                            ButtonSegment<int>(value: m, label: Text('$m min')),
                      )
                      .toList(),
                  selected: {_settings.tempAllowMinutes},
                  onSelectionChanged: quickAllowOn
                      ? (set) {
                          if (set.isEmpty) return;
                          _handleTempAllowChange(set.first);
                        }
                      : null,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppConstants.brandGreen.withAlpha(40);
                      }
                      return null;
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
