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

enum _GpsStatus { idle, fetching, success, denied, failed }

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
      if (!mounted) return;
      final isPermission = error.toString().toLowerCase().contains('permission');
      setState(() {
        _gpsStatus = isPermission ? _GpsStatus.denied : _GpsStatus.failed;
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

  Widget _buildJamaatCard(BuildContext context) {
    return _StepCard(
      stepNumber: '2',
      title: context.tr(bn: 'জামাতের মসজিদ', en: 'Jamaat Mosque'),
      description: context.tr(
        bn: 'জামাতের সময়ের জন্য একটি মসজিদ বেছে নিন।',
        en: 'Pick a mosque to receive its Jamaat times.',
      ),
      child: DropdownButtonFormField<String>(
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
    );
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
