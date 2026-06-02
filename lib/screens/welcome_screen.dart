import 'package:flutter/material.dart';

import '../core/app_theme_tokens.dart';
import '../core/constants.dart';
import '../core/locale_text.dart';
import '../models/jamaat_location.dart';
import '../models/location_config.dart';
import '../models/prayer_location.dart';
import '../services/location_config_service.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';

/// First-run setup screen. Asks the user to enable GPS for prayer times and
/// pick a mosque for Jamaat times. Marks `setup_complete = true` on dismissal
/// so it never shows again.
///
/// Both steps are optional — `Get Started` is always enabled. Skipping leaves
/// the corresponding state empty, and the home screen surfaces the appropriate
/// empty-state guidance (added in Phase 1).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.onCompleted});

  final VoidCallback onCompleted;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

enum _GpsStatus { idle, fetching, success, denied, serviceOff, failed }

class _WelcomeScreenState extends State<WelcomeScreen> {
  final LocationService _locationService = LocationService();
  final LocationConfigService _locationConfigService = LocationConfigService();
  final SettingsService _settingsService = SettingsService();

  _GpsStatus _gpsStatus = _GpsStatus.idle;
  String? _gpsLabel;
  String? _selectedMosque;
  bool _submitting = false;

  static const String _localMosqueValue = '__local_mosque__';

  Future<void> _enableLocation() async {
    if (_gpsStatus == _GpsStatus.fetching) return;
    setState(() {
      _gpsStatus = _GpsStatus.fetching;
    });

    try {
      final position = await _locationService.getCurrentPosition();
      final place = await _locationService.getPlaceName(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      final country = _locationConfigService.detectCountryFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final LocationConfig config;
      if (country == Country.saudiArabia) {
        final nearest = _locationConfigService.getNearestSaudiCity(
          position.latitude,
          position.longitude,
        );
        config = nearest != null
            ? _locationConfigService.getConfigForCity(nearest)
            : LocationConfig.world(
                place ?? 'Current Location',
                position.latitude,
                position.longitude,
              );
      } else if (country == Country.bangladesh) {
        config = LocationConfig(
          cityName: place ?? 'Current Location',
          country: Country.bangladesh,
          timezone: 'Asia/Dhaka',
          calculationMethodType: PrayerCalculationMethodType.muslimWorldLeague,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } else {
        config = LocationConfig.world(
          place ?? 'Current Location',
          position.latitude,
          position.longitude,
        );
      }

      final prayerLocation = PrayerLocation(
        mode: PrayerLocationMode.gps,
        latitude: position.latitude,
        longitude: position.longitude,
        locationName: place ?? 'Current Location',
        timezone: config.timezone,
        country: config.country,
        calculationMethodType: config.calculationMethodType,
      );
      await _settingsService.setPrayerLocation(prayerLocation);
      if (!mounted) return;
      setState(() {
        _gpsStatus = _GpsStatus.success;
        _gpsLabel = place ?? 'Current Location';
      });
    } catch (error) {
      // GPS toggled off at the system level is distinct from a denied app
      // permission — re-check the service state so we can guide the user to the
      // right place instead of a generic "try again".
      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      if (!mounted) return;
      final isPermission = error.toString().toLowerCase().contains('permission');
      setState(() {
        if (!serviceEnabled) {
          _gpsStatus = _GpsStatus.serviceOff;
        } else if (isPermission) {
          _gpsStatus = _GpsStatus.denied;
        } else {
          _gpsStatus = _GpsStatus.failed;
        }
      });
    }
  }

  Future<void> _onMosqueChanged(String? value) async {
    if (value == null) return;
    if (value == _localMosqueValue) {
      setState(() {
        _selectedMosque = _localMosqueValue;
      });
      await _settingsService.setJamaatLocation(
        const JamaatLocation(source: JamaatSource.local),
      );
      return;
    }
    setState(() {
      _selectedMosque = value;
    });
    await _settingsService.setJamaatLocation(
      JamaatLocation(
        source: JamaatSource.serverMosque,
        city: value,
        locationName: value,
      ),
    );
  }

  Future<void> _finish() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
    });
    await _settingsService.setSetupComplete(true);
    if (!mounted) return;
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Icon(
                Icons.mosque,
                size: 64,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(
                  bn: 'জামাত টাইমে স্বাগতম',
                  en: 'Welcome to Jamaat Time',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr(
                  bn: 'শুরু করতে নিচের দুটি ধাপ পূরণ করুন।',
                  en: 'Complete these two steps to get started.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView(
                  children: [
                    _buildPrayerCard(context),
                    const SizedBox(height: 16),
                    _buildJamaatCard(context),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _submitting ? null : _finish,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.primaryGreen,
                ),
                child: Text(
                  context.tr(bn: 'শুরু করুন', en: 'Get Started'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerCard(BuildContext context) {
    return _StepCard(
      stepNumber: '1',
      title: context.tr(bn: 'নামাজের সময়', en: 'Prayer Times'),
      description: context.tr(
        bn: 'আপনার অবস্থানের ভিত্তিতে নামাজের সময় গণনা করতে জিপিএস চালু করুন।',
        en: 'Enable GPS so prayer times are computed for your location.',
      ),
      child: _buildGpsControls(context),
    );
  }

  Widget _buildGpsControls(BuildContext context) {
    switch (_gpsStatus) {
      case _GpsStatus.idle:
      case _GpsStatus.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _enableLocation,
              icon: const Icon(Icons.my_location),
              label: Text(
                context.tr(bn: 'অবস্থান চালু করুন', en: 'Enable Location'),
              ),
            ),
            if (_gpsStatus == _GpsStatus.failed)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  context.tr(
                    bn: 'অবস্থান পাওয়া যায়নি। আবার চেষ্টা করুন।',
                    en: 'Could not get location. Please try again.',
                  ),
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
          ],
        );
      case _GpsStatus.fetching:
        return Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              context.tr(bn: 'অবস্থান শনাক্ত হচ্ছে...', en: 'Detecting location...'),
            ),
          ],
        );
      case _GpsStatus.success:
        return Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _gpsLabel ?? 'Location set',
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      case _GpsStatus.serviceOff:
        return _buildLocationOffGuidance(context);
      case _GpsStatus.denied:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr(
                bn: 'অবস্থানের অনুমতি প্রয়োজন। অ্যাপ সেটিংসে চালু করুন।',
                en: 'Location permission is required. Enable it in Settings.',
              ),
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _locationService.openLocationSettings(),
              icon: const Icon(Icons.settings),
              label: Text(
                context.tr(bn: 'সেটিংস খুলুন', en: 'Open Settings'),
              ),
            ),
          ],
        );
    }
  }

  /// Shown when the device's location services (GPS) are switched off. Carries
  /// a plain-language privacy declaration plus step-by-step guidance and a
  /// shortcut into the system location settings.
  Widget _buildLocationOffGuidance(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_off, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr(
                    bn: 'ডিভাইসের লোকেশন (GPS) বন্ধ আছে',
                    en: 'Location (GPS) is turned off',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              bn: 'আপনার এলাকার সঠিক নামাজের সময় গণনা করতে ডিভাইসের লোকেশন '
                  'চালু করা প্রয়োজন। আপনার অবস্থান শুধু এই ডিভাইসেই নামাজের সময় '
                  'গণনায় ব্যবহৃত হয় — কখনো শেয়ার বা সার্ভারে সংরক্ষণ করা হয় না।',
              en: 'Turning on your device location lets us calculate accurate '
                  'prayer times for where you are. Your location is used only '
                  'on this device for prayer-time calculation — it is never '
                  'shared or stored on our servers.',
            ),
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
              bn: 'করণীয়:\n১. নিচের বোতামে চাপ দিন\n'
                  '২. লোকেশন / অবস্থান চালু করুন\n'
                  '৩. এই স্ক্রিনে ফিরে এসে “আবার চেষ্টা করুন” চাপুন',
              en: 'Steps:\n1. Tap the button below\n'
                  '2. Turn on Location\n'
                  '3. Come back here and tap “Try Again”',
            ),
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _locationService.openLocationSettings(),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: AppColors.primaryGreen,
            ),
            icon: const Icon(Icons.location_on, size: 18),
            label: Text(
              context.tr(
                bn: 'লোকেশন সেটিংস খুলুন',
                en: 'Open Location Settings',
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _enableLocation,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(
              context.tr(bn: 'আবার চেষ্টা করুন', en: 'Try Again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJamaatCard(BuildContext context) {
    return _StepCard(
      stepNumber: '2',
      title: context.tr(bn: 'জামাতের মসজিদ', en: 'Jamaat Mosque'),
      description: context.tr(
        bn: 'জামাতের সময়ের জন্য একটি মসজিদ বেছে নিন।',
        en: 'Pick a mosque to receive its Jamaat times.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedMosque,
            isExpanded: true,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              hintText: context.tr(
                bn: 'মসজিদ নির্বাচন করুন',
                en: 'Select Mosque',
              ),
            ),
            items: _buildMosqueItems(),
            onChanged: _onMosqueChanged,
          ),
          _buildJamaatNotice(context),
        ],
      ),
    );
  }

  /// Contextual disclosure under the mosque picker:
  /// - nothing picked → warn that no Jamaat times / notifications will show;
  /// - Local Mosque → declare the bundled times are placeholders that must be
  ///   edited to the real local-mosque schedule for accurate times/reminders.
  Widget _buildJamaatNotice(BuildContext context) {
    if (_selectedMosque == null) {
      return _NoticeBox(
        icon: Icons.info_outline,
        color: Colors.orange,
        text: context.tr(
          bn: 'কোনো মসজিদ নির্বাচন না করলে আপনি কোনো জামাতের সময় দেখতে পাবেন '
              'না এবং জামাত সম্পর্কিত কোনো নোটিফিকেশনও পাবেন না।',
          en: 'If no mosque is selected, you will not see any Jamaat times '
              'and will not receive any Jamaat-related notifications.',
        ),
      );
    }
    if (_selectedMosque == _localMosqueValue) {
      return _NoticeBox(
        icon: Icons.warning_amber_rounded,
        color: Colors.deepOrange,
        text: context.tr(
          bn: 'লোকাল মসজিদের জন্য একটি ডিফল্ট (নমুনা) জামাত সময় সংরক্ষণ করা হয়, '
              'যা আপনার মসজিদের প্রকৃত সময় নয়। সঠিক সময় ও নোটিফিকেশন পেতে '
              'সেটিংস → লোকাল জামাত সময় থেকে আপনার মসজিদের সঠিক সময় দিয়ে এটি '
              'সম্পাদনা করুন।',
          en: 'A default (sample) Jamaat schedule is stored for Local Mosque — '
              'these are not your mosque\'s real times. To get accurate times '
              'and notifications, edit them with your mosque\'s actual schedule '
              'in Settings → Local Mosque Times.',
        ),
      );
    }
    return const SizedBox.shrink();
  }

  List<DropdownMenuItem<String>> _buildMosqueItems() {
    return <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: _localMosqueValue,
        child: Row(
          children: [
            const Icon(Icons.home_work, size: 16),
            const SizedBox(width: 6),
            Text(
              // Localized via the parent context below; this DropdownMenuItem
              // is built inside a context-aware closure but Material renders
              // each item with the dropdown's own ancestor — fall back to
              // English/Bangla concat so it's readable in both locales.
              context.tr(bn: 'লোকাল মসজিদ', en: 'Local Mosque'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      const DropdownMenuItem(
        enabled: false,
        value: null,
        child: Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            '🇧🇩 Bangladesh',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
      for (final city in AppConstants.bangladeshCities)
        DropdownMenuItem(value: city, child: Text(city)),
      const DropdownMenuItem(
        enabled: false,
        value: null,
        child: Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            '🇸🇦 Saudi Arabia',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
      for (final city in AppConstants.saudiCities)
        DropdownMenuItem(value: city, child: Text(city)),
    ];
  }
}

/// Small inline disclosure banner used under the mosque picker.
class _NoticeBox extends StatelessWidget {
  const _NoticeBox({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.child,
  });

  final String stepNumber;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primaryGreen,
                child: Text(
                  stepNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
