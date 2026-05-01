import 'package:flutter/material.dart';
import '../core/app_locale_controller.dart';
import '../core/feature_flags.dart';
import '../features/family_safety/presentation/family_safety_page.dart';
import '../l10n/app_localizations.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import 'focus_guard_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _brandGreen = Color(0xFF388E3C);
  static const double _cardRadius = 18;

  final SettingsService _settingsService = SettingsService();
  final NotificationService _notificationService = NotificationService();

  String _madhab = 'hanafi';
  String _locale = 'bn';
  int _bangladeshHijriOffsetDays =
      SettingsService.defaultBangladeshHijriOffsetDays;
  int _prayerNotificationSoundMode =
      0; // 0: Custom1, 1: System, 2: None, 3: Custom2, 4: Custom3
  int _jamaatNotificationSoundMode =
      0; // 0: Custom1, 1: System, 2: None, 3: Custom2, 4: Custom3
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
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

    if (!mounted) return;
    setState(() {
      _madhab = madhab;
      _locale = locale;
      _bangladeshHijriOffsetDays = bangladeshHijriOffset;
      _prayerNotificationSoundMode = prayerSoundMode;
      _jamaatNotificationSoundMode = jamaatSoundMode;
      _loading = false;
    });
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
                  ],
                ),
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
                        color: _brandGreen.withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: _brandGreen,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      _tr('ফোকাস গার্ড', 'Focus Guard'),
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      _tr(
                        'ফোকাস ধরে রাখতে YouTube Shorts ব্লক করুন।',
                        'Block YouTube Shorts to stay focused.',
                      ),
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
                          builder: (_) => const FocusGuardScreen(),
                        ),
                      );
                    },
                  ),
                ),
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
