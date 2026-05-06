import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import '../core/app_locale_controller.dart';
import '../core/feature_flags.dart';
import '../features/family_safety/presentation/family_safety_page.dart';
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
  static const double _cardRadius = 18;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  @override
  void dispose() {
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
  }

  Future<void> _refreshExactAlarmsStatus() async {
    if (!Platform.isAndroid) return;
    final granted = await _notificationService.refreshExactAlarmsAvailable();
    if (!mounted) return;
    setState(() => _exactAlarmsGranted = granted);
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

  Future<void> _updatePrayerSoundMode(int value) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    await _settingsService.setPrayerNotificationSoundMode(value);
    if (!mounted) return;
    setState(() => _prayerNotificationSoundMode = value);

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
      return;
    }
    final granted = await _autoVibrationService.hasDndAccess();
    if (granted) {
      await _settingsService.setAutoVibrationEnabled(true);
      if (!mounted) return;
      setState(() => _autoVibrationEnabled = true);
      return;
    }
    if (!mounted) return;
    setState(() => _autoVibrationPendingEnable = true);
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
    }
  }

  Future<void> _updateAutoVibrationMinutesBefore(int value) async {
    final clamped = value.clamp(0, SettingsService.maxAutoVibrationMinutesBefore);
    await _settingsService.setAutoVibrationMinutesBefore(clamped);
    if (!mounted) return;
    setState(() => _autoVibrationMinutesBefore = clamped);
  }

  Future<void> _updateAutoVibrationMinutesAfter(int value) async {
    final clamped = value.clamp(0, SettingsService.maxAutoVibrationMinutesAfter);
    await _settingsService.setAutoVibrationMinutesAfter(clamped);
    if (!mounted) return;
    setState(() => _autoVibrationMinutesAfter = clamped);
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
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
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
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
                    Text(
                      _tr('সঠিক সময়ের নোটিফিকেশন', 'Exact-time notifications'),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
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
          label: _tr(
            'জামাতের আগে (মিনিট)',
            'Minutes before jamaat',
          ),
          value: _autoVibrationMinutesBefore,
          min: 0,
          max: SettingsService.maxAutoVibrationMinutesBefore,
          enabled: _autoVibrationEnabled,
          onChanged: _updateAutoVibrationMinutesBefore,
        ),
        _buildStepperRow(
          label: _tr(
            'জামাতের পরে (মিনিট)',
            'Minutes after jamaat',
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('সেটিংস', 'Settings')),
        centerTitle: true,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  _tr(
                    'নামাজ গণনা ও রিমাইন্ডার আচরণ ঠিক করুন।',
                    'Fine-tune prayer calculations and reminder behavior.',
                  ),
                  style: TextStyle(color: Colors.grey[700], height: 1.3),
                ),
                const SizedBox(height: 14),
                _buildSectionCard(
                  icon: Icons.schedule,
                  color: const Color(0xFF2E7D32),
                  title: _tr('নামাজ গণনা', 'Prayer Calculation'),
                  subtitle: _tr(
                    'আপনার মাযহাব ও হিজরি তারিখ সমন্বয় ঠিক করুন।',
                    'Adjust your prayer school and Hijri date alignment.',
                  ),
                  children: [
                    _buildDropdownField<String>(
                      label: _tr('নামাজের মাযহাব', 'Prayer time school'),
                      initialValue: _madhab,
                      items: [
                        DropdownMenuItem(
                          value: 'hanafi',
                          child: Text(_tr('হানাফি', 'Hanafi')),
                        ),
                        DropdownMenuItem(
                          value: 'shafi',
                          child: Text(_tr('শাফেয়ী', 'Shafi')),
                        ),
                      ],
                      onChanged: (val) async {
                        if (val == null) return;
                        await _settingsService.setMadhab(val);
                        if (!mounted) return;
                        setState(() => _madhab = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownField<int>(
                      label: _tr(
                        'বাংলাদেশ হিজরি তারিখ সমন্বয়',
                        'Bangladesh Hijri date offset',
                      ),
                      initialValue: _bangladeshHijriOffsetDays,
                      items: [
                        DropdownMenuItem(
                          value: -2,
                          child: Text(_hijriOffsetLabel(-2)),
                        ),
                        DropdownMenuItem(
                          value: -1,
                          child: Text(_hijriOffsetLabel(-1)),
                        ),
                        DropdownMenuItem(
                          value: 0,
                          child: Text(_hijriOffsetLabel(0)),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text(_hijriOffsetLabel(1)),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text(_hijriOffsetLabel(2)),
                        ),
                      ],
                      onChanged: (val) async {
                        if (val == null) return;
                        await _settingsService.setBangladeshHijriOffsetDays(
                          val,
                        );
                        if (!mounted) return;
                        setState(() => _bangladeshHijriOffsetDays = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (kLanguageSwitchEnabled) ...[
                  _buildSectionCard(
                    icon: Icons.language,
                    color: const Color(0xFF6A1B9A),
                    title: AppLocalizations.of(
                      context,
                    ).settings_languageSection,
                    subtitle: AppLocalizations.of(
                      context,
                    ).settings_languageSubtitle,
                    children: [
                      _buildDropdownField<String>(
                        label: AppLocalizations.of(
                          context,
                        ).settings_languageLabel,
                        initialValue: _locale,
                        items: [
                          DropdownMenuItem(
                            value: 'bn',
                            child: Text(
                              AppLocalizations.of(
                                context,
                              ).settings_languageBangla,
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'en',
                            child: Text(
                              AppLocalizations.of(
                                context,
                              ).settings_languageEnglish,
                            ),
                          ),
                        ],
                        onChanged: (val) async {
                          if (val == null) return;
                          await _updateLocale(val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
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
                      label: _tr(
                        'নামাজ রিমাইন্ডার সাউন্ড',
                        'Prayer reminder sound',
                      ),
                      initialValue: _prayerNotificationSoundMode,
                      items: [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(_soundModeLabel(0)),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text(_soundModeLabel(3)),
                        ),
                        DropdownMenuItem(
                          value: 4,
                          child: Text(_soundModeLabel(4)),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text(_soundModeLabel(1)),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text(_soundModeLabel(2)),
                        ),
                      ],
                      onChanged: (val) async {
                        if (val == null) return;
                        await _updatePrayerSoundMode(val);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDropdownField<int>(
                      label: _tr(
                        'জামাত রিমাইন্ডার সাউন্ড',
                        'Jamaat reminder sound',
                      ),
                      initialValue: _jamaatNotificationSoundMode,
                      items: [
                        DropdownMenuItem(
                          value: 0,
                          child: Text(_soundModeLabel(0)),
                        ),
                        DropdownMenuItem(
                          value: 3,
                          child: Text(_soundModeLabel(3)),
                        ),
                        DropdownMenuItem(
                          value: 4,
                          child: Text(_soundModeLabel(4)),
                        ),
                        DropdownMenuItem(
                          value: 1,
                          child: Text(_soundModeLabel(1)),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text(_soundModeLabel(2)),
                        ),
                      ],
                      onChanged: (val) async {
                        if (val == null) return;
                        await _updateJamaatSoundMode(val);
                      },
                    ),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      value: _fajrVoiceNotificationEnabled,
                      onChanged: _updateFajrVoiceNotification,
                      activeTrackColor: _brandGreen,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _tr(
                          'ফজর ভয়েস নোটিফিকেশন',
                          'Fajr voice notification',
                        ),
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
                if (Platform.isAndroid) ...[
                  const SizedBox(height: 12),
                  _buildAutoVibrationCard(),
                ],
                const SizedBox(height: 12),
                Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_cardRadius),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00897B).withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.family_restroom_outlined,
                        color: Color(0xFF00897B),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      AppLocalizations.of(context).familySafetyTitle,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context).familySafetySubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.35,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FamilySafetyPage(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _tr(
                      'বর্তমান সেটআপ: ${_madhab.toUpperCase()} · '
                          'হিজরি ${_hijriOffsetLabel(_bangladeshHijriOffsetDays)} · '
                          'নামাজ ${_soundModeLabel(_prayerNotificationSoundMode)} · '
                          'জামাত ${_soundModeLabel(_jamaatNotificationSoundMode)}',
                      'Current setup: ${_madhab.toUpperCase()} · '
                          'Hijri ${_hijriOffsetLabel(_bangladeshHijriOffsetDays)} · '
                          'Prayer ${_soundModeLabel(_prayerNotificationSoundMode)} · '
                          'Jamaat ${_soundModeLabel(_jamaatNotificationSoundMode)}',
                    ),
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
    );
  }
}
