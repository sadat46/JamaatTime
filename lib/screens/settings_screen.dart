import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/app_locale_controller.dart';
import '../core/feature_flags.dart';
import '../features/family_safety/presentation/family_safety_page.dart';
import '../features/family_safety/presentation/privacy_explanation_page.dart';
import '../l10n/app_localizations.dart';
import '../services/auto_vibration_service.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  static const Color _brandGreen = Color(0xFF388E3C);

  final SettingsService _settingsService = SettingsService();
  final NotificationService _notificationService = NotificationService();
  final AutoVibrationService _autoVibrationService = AutoVibrationService();

  String _madhab = 'hanafi';
  String _locale = 'bn';
  int _bangladeshHijriOffsetDays =
      SettingsService.defaultBangladeshHijriOffsetDays;
  int _prayerNotificationSoundMode =
      0; // 0: Custom1, 1: System, 2: None, 3: Custom2, 4: Custom3
  int _jamaatNotificationSoundMode =
      0; // 0: Custom1, 1: System, 2: None, 3: Custom2, 4: Custom3
  bool _fajrVoiceNotificationEnabled = false;
  bool _exactAlarmsGranted = true;
  bool _autoVibrationEnabled = false;
  int _autoVibrationMinutesBefore =
      SettingsService.defaultAutoVibrationMinutesBefore;
  int _autoVibrationMinutesAfter =
      SettingsService.defaultAutoVibrationMinutesAfter;
  bool _autoVibrationPendingEnable = false;
  bool _loading = true;
  String _appVersion = '';
  VoidCallback? _activeSubpageRefresh;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _loadAppVersion();
  }

  @override
  void dispose() {
    _activeSubpageRefresh = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // After the user returns from the system "Alarms & reminders" page, sync
    // the displayed status with the OS-level state.
    if (state == AppLifecycleState.resumed) {
      _refreshExactAlarmsStatus();
      _resolvePendingAutoVibrationEnable();
    }
  }

  Future<void> _resolvePendingAutoVibrationEnable() async {
    if (!_autoVibrationPendingEnable || !Platform.isAndroid) return;
    final granted = await _autoVibrationService.hasDndAccess();
    if (!mounted || !granted) return;
    await _settingsService.setAutoVibrationEnabled(true);
    if (!mounted) return;
    setState(() {
      _autoVibrationEnabled = true;
      _autoVibrationPendingEnable = false;
    });
    _refreshOpenSubpage();
  }

  Future<void> _loadSettings() async {
    final madhab = await _settingsService.getMadhab();
    final locale = await _settingsService.getLocale();
    final bangladeshHijriOffset = await _settingsService
        .getBangladeshHijriOffsetDays();
    final prayerSoundMode = await _settingsService
        .getPrayerNotificationSoundMode();
    final jamaatSoundMode = await _settingsService
        .getJamaatNotificationSoundMode();
    final fajrVoiceEnabled = await _settingsService
        .getFajrVoiceNotificationEnabled();
    final exactAlarms = Platform.isAndroid
        ? await _notificationService.refreshExactAlarmsAvailable()
        : true;
    final autoVibrationEnabled = await _settingsService
        .getAutoVibrationEnabled();
    final autoVibrationBefore = await _settingsService
        .getAutoVibrationMinutesBefore();
    final autoVibrationAfter = await _settingsService
        .getAutoVibrationMinutesAfter();

    if (!mounted) return;
    setState(() {
      _madhab = madhab;
      _locale = locale;
      _bangladeshHijriOffsetDays = bangladeshHijriOffset;
      _prayerNotificationSoundMode = prayerSoundMode;
      _jamaatNotificationSoundMode = jamaatSoundMode;
      _fajrVoiceNotificationEnabled = fajrVoiceEnabled;
      _exactAlarmsGranted = exactAlarms;
      _autoVibrationEnabled = autoVibrationEnabled;
      _autoVibrationMinutesBefore = autoVibrationBefore;
      _autoVibrationMinutesAfter = autoVibrationAfter;
      _loading = false;
    });
    _refreshOpenSubpage();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = 'v ${info.version} (${info.buildNumber})';
      });
      _refreshOpenSubpage();
    } catch (_) {
      // Version is supplemental; keep the About page usable if unavailable.
    }
  }

  Future<void> _refreshExactAlarmsStatus() async {
    if (!Platform.isAndroid) return;
    final granted = await _notificationService.refreshExactAlarmsAvailable();
    if (!mounted) return;
    setState(() => _exactAlarmsGranted = granted);
    _refreshOpenSubpage();
  }

  Future<void> _grantExactAlarms() async {
    if (!Platform.isAndroid) return;
    await _notificationService.requestExactAlarmsPermission();
    // The grant flow opens the system settings page; user returns to the app
    // afterward. Re-check on next frame to reflect their choice.
    await _refreshExactAlarmsStatus();
  }

  Future<void> _updateLocale(String code) async {
    await _settingsService.setLocale(code);
    await AppLocaleController.instance.set(code);
    if (!mounted) return;
    setState(() => _locale = code);
    _refreshOpenSubpage();
  }

  void _refreshOpenSubpage() {
    _activeSubpageRefresh?.call();
  }

  Future<void> _updateMadhab(String value) async {
    await _settingsService.setMadhab(value);
    if (!mounted) return;
    setState(() => _madhab = value);
    _refreshOpenSubpage();
  }

  Future<void> _updateBangladeshHijriOffset(int value) async {
    await _settingsService.setBangladeshHijriOffsetDays(value);
    if (!mounted) return;
    setState(() => _bangladeshHijriOffsetDays = value);
    _refreshOpenSubpage();
  }

  String _tr(String bn, String en) => _locale == 'en' ? en : bn;

  String _soundModeLabel(int value) {
    switch (value) {
      case 1:
        return _tr('সিস্টেম সাউন্ড', 'System sound');
      case 2:
        return _tr('নিঃশব্দ', 'No sound');
      case 3:
        return _tr('কল সাউন্ড শর্ট ১', 'Call Sound Short 1');
      case 4:
        return _tr('কল সাউন্ড শর্ট ২', 'Call Sound short 2');
      default:
        return _tr('আযান সাউন্ড', 'Adhan sound');
    }
  }

  String _hijriOffsetLabel(int value) {
    final dayWord = _tr('দিন', 'day');
    final dayWordPlural = _tr('দিন', 'days');
    final suffix = value.abs() == 1 ? dayWord : dayWordPlural;
    if (value == 0) {
      return '0 $suffix';
    }
    if (value > 0) {
      return '+$value $suffix';
    }
    return '$value $suffix';
  }

  String _madhabLabel(String value) {
    return value == 'shafi' ? _tr('শাফেয়ী', 'Shafi') : _tr('হানাফি', 'Hanafi');
  }

  String _localeLabel(String value) {
    return value == 'en'
        ? AppLocalizations.of(context).settings_languageEnglish
        : AppLocalizations.of(context).settings_languageBangla;
  }

  String _autoVibrationWindowLabel() {
    return _tr(
      '$_autoVibrationMinutesBefore মিনিট আগে, $_autoVibrationMinutesAfter মিনিট পরে',
      '${_autoVibrationMinutesBefore}m before, ${_autoVibrationMinutesAfter}m after',
    );
  }

  Future<void> _updatePrayerSoundMode(int value) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await _settingsService.setPrayerNotificationSoundMode(value);
    if (!mounted) return;
    setState(() => _prayerNotificationSoundMode = value);
    _refreshOpenSubpage();

    try {
      await _notificationService.handleNotificationSoundModeChange();
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'নামাজ রিমাইন্ডার সাউন্ড আপডেট হয়েছে।',
              'Prayer reminder sound updated.',
            ),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'নামাজ নোটিফিকেশন সেটিংস আপডেট করতে সমস্যা: $e',
              'Error updating prayer notification settings: $e',
            ),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _updateJamaatSoundMode(int value) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await _settingsService.setJamaatNotificationSoundMode(value);
    if (!mounted) return;
    setState(() => _jamaatNotificationSoundMode = value);
    _refreshOpenSubpage();

    try {
      await _notificationService.handleNotificationSoundModeChange();
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'জামাত রিমাইন্ডার সাউন্ড আপডেট হয়েছে।',
              'Jamaat reminder sound updated.',
            ),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'জামাত নোটিফিকেশন সেটিংস আপডেট করতে সমস্যা: $e',
              'Error updating jamaat notification settings: $e',
            ),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _updateFajrVoiceNotification(bool value) async {
    await _settingsService.setFajrVoiceNotificationEnabled(value);
    if (!mounted) return;
    setState(() => _fajrVoiceNotificationEnabled = value);
    _refreshOpenSubpage();
  }

  Future<void> _updateAutoVibrationEnabled(bool value) async {
    if (!Platform.isAndroid) return;
    if (!value) {
      await _settingsService.setAutoVibrationEnabled(false);
      if (!mounted) return;
      setState(() {
        _autoVibrationEnabled = false;
        _autoVibrationPendingEnable = false;
      });
      _refreshOpenSubpage();
      return;
    }
    final granted = await _autoVibrationService.hasDndAccess();
    if (granted) {
      await _settingsService.setAutoVibrationEnabled(true);
      if (!mounted) return;
      setState(() => _autoVibrationEnabled = true);
      _refreshOpenSubpage();
      return;
    }
    if (!mounted) return;
    setState(() => _autoVibrationPendingEnable = true);
    _refreshOpenSubpage();
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_tr('অনুমতি প্রয়োজন', 'Permission required')),
        content: Text(
          _tr(
            'জামাতের সময় ফোন অটো ভাইব্রেট করতে "Do Not Disturb" এক্সেস প্রয়োজন। সেটিংস খুলে অনুমতি দিন।',
            'To switch your phone to vibrate around jamaat time, allow Do Not Disturb access in system settings.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(_tr('পরে', 'Later')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_tr('সেটিংস খুলুন', 'Open settings')),
          ),
        ],
      ),
    );
    if (shouldOpen == true) {
      await _autoVibrationService.openDndSettings();
    } else {
      if (!mounted) return;
      setState(() => _autoVibrationPendingEnable = false);
      _refreshOpenSubpage();
    }
  }

  Future<void> _updateAutoVibrationMinutesBefore(int value) async {
    final clamped = value.clamp(
      0,
      SettingsService.maxAutoVibrationMinutesBefore,
    );
    await _settingsService.setAutoVibrationMinutesBefore(clamped);
    if (!mounted) return;
    setState(() => _autoVibrationMinutesBefore = clamped);
    _refreshOpenSubpage();
  }

  Future<void> _updateAutoVibrationMinutesAfter(int value) async {
    final clamped = value.clamp(
      0,
      SettingsService.maxAutoVibrationMinutesAfter,
    );
    await _settingsService.setAutoVibrationMinutesAfter(clamped);
    if (!mounted) return;
    setState(() => _autoVibrationMinutesAfter = clamped);
    _refreshOpenSubpage();
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return SettingsSectionCard(
      icon: icon,
      color: color,
      title: title,
      subtitle: subtitle,
      children: children,
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? chip,
  }) {
    return SettingsMenuCard(
      icon: icon,
      color: color,
      title: title,
      subtitle: subtitle,
      chip: chip,
      onTap: onTap,
    );
  }

  Widget _buildExactAlarmTile() {
    final granted = _exactAlarmsGranted;
    final accent = granted ? _brandGreen : const Color(0xFFD84315);
    final statusLabel = granted
        ? _tr('অনুমোদিত', 'Granted')
        : _tr('অনুমতি দেওয়া নেই', 'Not granted');
    final descriptionLabel = granted
        ? _tr(
            'অ্যালার্ম ও রিমাইন্ডার অনুমতি চালু আছে — সঠিক সময়ে নোটিফিকেশন আসবে।',
            'Alarms & reminders permission is on — notifications will fire at the exact time.',
          )
        : _tr(
            'অনুমতি বন্ধ থাকলে নোটিফিকেশন ১০ মিনিট পর্যন্ত দেরিতে আসতে পারে।',
            'Without this permission notifications may arrive up to ~10 minutes late.',
          );

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            granted ? Icons.alarm_on : Icons.alarm_off,
            size: 20,
            color: accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _tr(
                          'সঠিক সময়ের নোটিফিকেশন',
                          'Exact-time notifications',
                        ),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  descriptionLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (!granted) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: _grantExactAlarms,
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(_tr('অনুমতি দিন', 'Grant')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepperRow({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
    required bool enabled,
  }) {
    final canDec = enabled && value > min;
    final canInc = enabled && value < max;
    final accent = enabled ? _brandGreen : Colors.grey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: enabled ? null : Colors.grey,
              ),
            ),
          ),
          IconButton(
            onPressed: canDec ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: accent,
            iconSize: 26,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 56,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: enabled ? null : Colors.grey,
              ),
            ),
          ),
          IconButton(
            onPressed: canInc ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
            color: accent,
            iconSize: 26,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildAutoVibrationCard() {
    return _buildSectionCard(
      icon: Icons.vibration,
      color: const Color(0xFF6D4C41),
      title: _tr('অটো ভাইব্রেশন মোড', 'Auto vibration mode'),
      subtitle: _tr(
        'জামাতের সময় ফোন স্বয়ংক্রিয়ভাবে ভাইব্রেট মোডে যাবে এবং পরে আগের অবস্থায় ফিরবে।',
        'Switches the phone to vibrate around jamaat and restores it afterward.',
      ),
      children: [
        SwitchListTile(
          value: _autoVibrationEnabled,
          onChanged: _updateAutoVibrationEnabled,
          activeTrackColor: _brandGreen,
          contentPadding: EdgeInsets.zero,
          title: Text(
            _tr('চালু করুন', 'Enable'),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _tr(
              'প্রতিটি জামাতের আগে ও পরে নির্ধারিত সময়ের জন্য সক্রিয় থাকবে।',
              'Active for the configured window around each jamaat.',
            ),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        _buildStepperRow(
          label: _tr('জামাতের আগে (মিনিট)', 'Minutes before jamaat'),
          value: _autoVibrationMinutesBefore,
          min: 0,
          max: SettingsService.maxAutoVibrationMinutesBefore,
          enabled: _autoVibrationEnabled,
          onChanged: _updateAutoVibrationMinutesBefore,
        ),
        _buildStepperRow(
          label: _tr('জামাতের পরে (মিনিট)', 'Minutes after jamaat'),
          value: _autoVibrationMinutesAfter,
          min: 0,
          max: SettingsService.maxAutoVibrationMinutesAfter,
          enabled: _autoVibrationEnabled,
          onChanged: _updateAutoVibrationMinutesAfter,
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T initialValue,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: initialValue,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
          borderRadius: BorderRadius.circular(12),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _brandGreen, width: 1.4),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openSettingsSubpage(
    Widget Function(BuildContext context) builder,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (routeContext, setRouteState) {
            _activeSubpageRefresh = () {
              if (routeContext.mounted) {
                setRouteState(() {});
              }
            };
            return builder(routeContext);
          },
        ),
      ),
    );
    _activeSubpageRefresh = null;
    if (!mounted) return;
    await _loadSettings();
  }

  Widget _buildSubpageScaffold({
    required String title,
    required List<Widget> children,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFFFFCF7),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: children,
        ),
      ),
    );
  }

  List<DropdownMenuItem<int>> _soundModeItems() {
    return [
      DropdownMenuItem(value: 0, child: Text(_soundModeLabel(0))),
      DropdownMenuItem(value: 3, child: Text(_soundModeLabel(3))),
      DropdownMenuItem(value: 4, child: Text(_soundModeLabel(4))),
      DropdownMenuItem(value: 1, child: Text(_soundModeLabel(1))),
      DropdownMenuItem(value: 2, child: Text(_soundModeLabel(2))),
    ];
  }

  Widget _buildPrayerDatePage(BuildContext context) {
    return _buildSubpageScaffold(
      title: _tr('নামাজ ও তারিখ', 'Prayer & Date'),
      children: [
        _buildSectionCard(
          icon: Icons.schedule,
          color: const Color(0xFF2E7D32),
          title: _tr('নামাজ ও তারিখ', 'Prayer & Date'),
          subtitle: _tr(
            'মাযহাব এবং বাংলাদেশের হিজরি তারিখ সমন্বয়।',
            'Madhab and Bangladesh Hijri date offset.',
          ),
          children: [
            _buildDropdownField<String>(
              label: _tr('নামাজের মাযহাব', 'Prayer time school'),
              initialValue: _madhab,
              items: [
                DropdownMenuItem(
                  value: 'hanafi',
                  child: Text(_madhabLabel('hanafi')),
                ),
                DropdownMenuItem(
                  value: 'shafi',
                  child: Text(_madhabLabel('shafi')),
                ),
              ],
              onChanged: (val) async {
                if (val == null) return;
                await _updateMadhab(val);
              },
            ),
            const SizedBox(height: 14),
            _buildDropdownField<int>(
              label: _tr(
                'বাংলাদেশ হিজরি তারিখ সমন্বয়',
                'Bangladesh Hijri date offset',
              ),
              initialValue: _bangladeshHijriOffsetDays,
              items: [
                DropdownMenuItem(value: -2, child: Text(_hijriOffsetLabel(-2))),
                DropdownMenuItem(value: -1, child: Text(_hijriOffsetLabel(-1))),
                DropdownMenuItem(value: 0, child: Text(_hijriOffsetLabel(0))),
                DropdownMenuItem(value: 1, child: Text(_hijriOffsetLabel(1))),
                DropdownMenuItem(value: 2, child: Text(_hijriOffsetLabel(2))),
              ],
              onChanged: (val) async {
                if (val == null) return;
                await _updateBangladeshHijriOffset(val);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguagePage(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return _buildSubpageScaffold(
      title: strings.settings_languageSection,
      children: [
        _buildSectionCard(
          icon: Icons.language,
          color: const Color(0xFF6A1B9A),
          title: strings.settings_languageSection,
          subtitle: strings.settings_languageSubtitle,
          children: [
            _buildDropdownField<String>(
              label: strings.settings_languageLabel,
              initialValue: _locale,
              items: [
                DropdownMenuItem(
                  value: 'bn',
                  child: Text(strings.settings_languageBangla),
                ),
                DropdownMenuItem(
                  value: 'en',
                  child: Text(strings.settings_languageEnglish),
                ),
              ],
              onChanged: (val) async {
                if (val == null) return;
                await _updateLocale(val);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationsPage(BuildContext context) {
    return _buildSubpageScaffold(
      title: _tr('নোটিফিকেশন', 'Notifications'),
      children: [
        _buildSectionCard(
          icon: Icons.notifications_active,
          color: const Color(0xFF1565C0),
          title: _tr('নোটিফিকেশন', 'Notifications'),
          subtitle: _tr(
            'নামাজ ও জামাত রিমাইন্ডারের সাউন্ড নির্বাচন করুন।',
            'Choose sound behavior for prayer and jamaat reminders.',
          ),
          children: [
            _buildDropdownField<int>(
              label: _tr('নামাজ রিমাইন্ডার সাউন্ড', 'Prayer reminder sound'),
              initialValue: _prayerNotificationSoundMode,
              items: _soundModeItems(),
              onChanged: (val) async {
                if (val == null) return;
                await _updatePrayerSoundMode(val);
              },
            ),
            const SizedBox(height: 14),
            _buildDropdownField<int>(
              label: _tr('জামাত রিমাইন্ডার সাউন্ড', 'Jamaat reminder sound'),
              initialValue: _jamaatNotificationSoundMode,
              items: _soundModeItems(),
              onChanged: (val) async {
                if (val == null) return;
                await _updateJamaatSoundMode(val);
              },
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              value: _fajrVoiceNotificationEnabled,
              onChanged: _updateFajrVoiceNotification,
              activeTrackColor: _brandGreen,
              contentPadding: EdgeInsets.zero,
              title: Text(
                _tr('ফজর ভয়েস নোটিফিকেশন', 'Fajr voice notification'),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _tr(
                  'ফজরের ওয়াক্ত শুরু হলে ভয়েস রিমাইন্ডার বাজবে।',
                  'Play voice reminder when Fajr time starts.',
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (Platform.isAndroid) _buildExactAlarmTile(),
          ],
        ),
      ],
    );
  }

  Widget _buildAutoVibrationPage(BuildContext context) {
    return _buildSubpageScaffold(
      title: _tr('অটো ভাইব্রেশন', 'Auto Vibration'),
      children: [_buildAutoVibrationCard()],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: _brandGreen, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFF8A8F88)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAboutHelpPage(BuildContext context) {
    return _buildSubpageScaffold(
      title: _tr('পরিচিতি ও সহায়তা', 'About & Help'),
      children: [
        _buildSectionCard(
          icon: Icons.help_outline,
          color: const Color(0xFF455A64),
          title: _tr('পরিচিতি ও সহায়তা', 'About & Help'),
          subtitle: _tr(
            'অ্যাপের তথ্য, সহায়তা এবং প্রাইভেসি।',
            'App information, support, and privacy.',
          ),
          children: [
            _buildInfoRow(
              icon: Icons.info_outline,
              title: _tr('ভার্সন', 'Version'),
              subtitle: _appVersion.isEmpty
                  ? _tr('ভার্সন পাওয়া যায়নি', 'Version unavailable')
                  : _appVersion,
            ),
            const Divider(height: 20),
            _buildInfoRow(
              icon: Icons.support_agent,
              title: _tr('সহায়তা / যোগাযোগ', 'Help / Contact'),
              subtitle: _tr(
                'সহায়তার জন্য অ্যাপ মেইনটেইনার বা আপনার স্থানীয় অ্যাডমিনের সঙ্গে যোগাযোগ করুন।',
                'For support, contact the app maintainer or your local admin.',
              ),
            ),
            const Divider(height: 20),
            _buildInfoRow(
              icon: Icons.privacy_tip_outlined,
              title: _tr('প্রাইভেসি', 'Privacy'),
              subtitle: _tr(
                'ফ্যামিলি সেফটি প্রাইভেসি তথ্য দেখুন।',
                'View Family Safety privacy details.',
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrivacyExplanationPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('সেটিংস', 'Settings')),
        centerTitle: true,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFFFFCF7),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _buildMenuCard(
                  icon: Icons.schedule,
                  color: const Color(0xFF2E7D32),
                  title: _tr('নামাজ ও তারিখ', 'Prayer & Date'),
                  subtitle: _tr(
                    'মাযহাব, হিজরি সমন্বয়',
                    'Madhab, Hijri offset',
                  ),
                  chip:
                      '${_madhabLabel(_madhab)} · ${_hijriOffsetLabel(_bangladeshHijriOffsetDays)}',
                  onTap: () => _openSettingsSubpage(_buildPrayerDatePage),
                ),
                const SizedBox(height: 12),
                if (kLanguageSwitchEnabled) ...[
                  _buildMenuCard(
                    icon: Icons.language,
                    color: const Color(0xFF6A1B9A),
                    title: strings.settings_languageSection,
                    subtitle: _tr(
                      'অ্যাপের ভাষা: English/বাংলা',
                      'App language: English/Bangla',
                    ),
                    chip: _localeLabel(_locale),
                    onTap: () => _openSettingsSubpage(_buildLanguagePage),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildMenuCard(
                  icon: Icons.notifications_active,
                  color: const Color(0xFF1565C0),
                  title: _tr('নোটিফিকেশন', 'Notifications'),
                  subtitle: _tr(
                    'নামাজ সাউন্ড, জামাত সাউন্ড, ফজর ভয়েস',
                    'Prayer sound, Jamaat sound, Fajr voice',
                  ),
                  onTap: () => _openSettingsSubpage(_buildNotificationsPage),
                ),
                if (Platform.isAndroid) ...[
                  const SizedBox(height: 12),
                  _buildMenuCard(
                    icon: Icons.vibration,
                    color: const Color(0xFF6D4C41),
                    title: _tr('অটো ভাইব্রেশন মোড', 'Auto Vibration Mode'),
                    subtitle: _tr(
                      'জামাতের সময়ের আশেপাশে',
                      'Around Jamaat times',
                    ),
                    chip: _autoVibrationWindowLabel(),
                    onTap: () => _openSettingsSubpage(_buildAutoVibrationPage),
                  ),
                ],
                const SizedBox(height: 12),
                _buildMenuCard(
                  icon: Icons.family_restroom_outlined,
                  color: const Color(0xFF00897B),
                  title: strings.familySafetyTitle,
                  subtitle: _tr(
                    'ওয়েবসাইট সুরক্ষা, ডিজিটাল ওয়েলবিয়িং',
                    'Website protection, digital wellbeing',
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FamilySafetyPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildMenuCard(
                  icon: Icons.help_outline,
                  color: const Color(0xFF455A64),
                  title: _tr('পরিচিতি ও সহায়তা', 'About & Help'),
                  subtitle: _tr(
                    'ভার্সন, প্রাইভেসি, সাপোর্ট',
                    'Version, privacy, support',
                  ),
                  chip: _appVersion.isEmpty ? null : _appVersion,
                  onTap: () => _openSettingsSubpage(_buildAboutHelpPage),
                ),
              ],
            ),
    );
  }
}

class SettingsMenuCard extends StatelessWidget {
  const SettingsMenuCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.chip,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2.5,
      shadowColor: Colors.black.withAlpha(18),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEAF0E7)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withAlpha(24),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1D251E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.25,
                        color: Color(0xFF667067),
                      ),
                    ),
                    if (chip != null && chip!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 190),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withAlpha(18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: color.withAlpha(36)),
                          ),
                          child: Text(
                            chip!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFF8A8F88)),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withAlpha(16),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEAF0E7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withAlpha(24),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1D251E),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: Color(0xFF667067),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}
