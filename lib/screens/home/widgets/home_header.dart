import 'package:flutter/material.dart';

import '../../../core/app_theme_tokens.dart';
import '../../../core/constants.dart';
import '../../../core/locale_text.dart';
import '../../../models/jamaat_location.dart';
import '../../../models/location_config.dart';
import '../../../services/hijri_date_converter.dart';
import '../../../utils/bangla_calendar.dart';
import '../../../utils/date_format_cache.dart';
import '../../../utils/locale_digits.dart';
import '../../../widgets/live_clock_widget.dart';
import '../../../widgets/prayer_countdown_widget.dart';
import '../home_controller.dart';
import 'notice_action_button.dart';

class _HomeHeaderLayout {
  const _HomeHeaderLayout({
    required this.maxHeaderWidth,
    required this.horizontalPadding,
    required this.cardHorizontalPadding,
    required this.countdownGap,
    required this.topPadding,
  });

  factory _HomeHeaderLayout.from(
    BuildContext context,
    BoxConstraints pageConstraints,
  ) {
    final isCompact = pageConstraints.maxWidth < 400;
    return _HomeHeaderLayout(
      maxHeaderWidth: pageConstraints.maxWidth < 600
          ? pageConstraints.maxWidth
          : 600.0,
      horizontalPadding: isCompact ? 16.0 : 20.0,
      cardHorizontalPadding: isCompact ? 14.0 : 18.0,
      countdownGap: isCompact ? 16.0 : 28.0,
      topPadding: MediaQuery.of(context).viewPadding.top,
    );
  }

  final double maxHeaderWidth;
  final double horizontalPadding;
  final double cardHorizontalPadding;
  final double countdownGap;
  final double topPadding;
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.controller,
    required this.pageConstraints,
    this.noticeAction,
  });

  final HomeController controller;
  final BoxConstraints pageConstraints;
  final Widget? noticeAction;

  @override
  Widget build(BuildContext context) {
    final layout = _HomeHeaderLayout.from(context, pageConstraints);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final localeCode = Localizations.localeOf(context).languageCode == 'en'
            ? 'en'
            : 'bn';
        final dateStr = _localizedDigitsForContext(
          context,
          DateFormatCache.get(
            'EEE, d MMM, yyyy',
            localeCode,
          ).format(controller.selectedDate),
        );
        final hijriStr = _toHijriString(controller.selectedDate);
        final banglaDateStr = BanglaCalendar.fromGregorian(
          controller.selectedDate,
        );

        return _buildHeader(
          context,
          layout: layout,
          dateStr: dateStr,
          hijriStr: hijriStr,
          banglaDateStr: banglaDateStr,
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required _HomeHeaderLayout layout,
    required String dateStr,
    required String hijriStr,
    required String banglaDateStr,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D4A26), AppColors.primaryDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: layout.maxHeaderWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              layout.horizontalPadding,
              layout.topPadding + 10,
              layout.horizontalPadding,
              14,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 44, height: 44),
                    Expanded(
                      child: Text(
                        context.tr(bn: 'জামাত টাইম', en: 'Jamaat Time'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                      ),
                    ),
                    noticeAction ??
                        NoticeActionButton(
                          repository: controller.noticeRepository,
                          readState: controller.noticeReadState,
                        ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F5E2D), Color(0xFF18723A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF042414).withValues(alpha: 0.34),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: layout.cardHorizontalPadding,
                      vertical: 16.0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        PrayerCountdownWidget(
                          prayerTimes: controller.times,
                          selectedDate: controller.selectedDate,
                          coordinates: controller.coords,
                          calculationParams: controller.calculationParams,
                          isActive: controller.shouldRunHomeTimer,
                          textStyle: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          specialTextStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: layout.countdownGap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DropdownButton<String>(
                                isExpanded: true,
                                value: _dropdownValueFor(controller),
                                hint: Text(
                                  context.tr(
                                    bn: 'মসজিদ নির্বাচন করুন',
                                    en: 'Select Mosque',
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                                items: _buildCityDropdownItems(context),
                                dropdownColor: AppColors.primaryDark,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                                iconEnabledColor: Colors.white70,
                                underline: Container(
                                  height: 1,
                                  color: Colors.white38,
                                ),
                                isDense: true,
                                padding: EdgeInsets.zero,
                                onChanged: (value) async {
                                  if (value == null) return;
                                  if (value == _localMosqueValue) {
                                    if (controller.jamaatLocation.source ==
                                        JamaatSource.local) {
                                      return;
                                    }
                                    await controller.selectLocalMosque();
                                    return;
                                  }
                                  if (value == controller.selectedCity) return;
                                  await controller.selectJamaatMosque(value);
                                },
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  LiveClockWidget(
                                    isActive: controller.shouldRunHomeTimer,
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                hijriStr,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                banglaDateStr,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => _fetchUserLocation(context),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.my_location,
                                      size: 16,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: _buildGpsRowChild(context),
                                    ),
                                  ],
                                ),
                              ),
                              if (controller.isLoadingJamaat)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          context.tr(
                                            bn: 'জামাত সময় লোড হচ্ছে...',
                                            en: 'Loading jamaat times...',
                                          ),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white60,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (controller.jamaatError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error,
                                        size: 14,
                                        color: Colors.orangeAccent,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          controller.jamaatError!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.orangeAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGpsRowChild(BuildContext context) {
    if (controller.currentPlaceName != null) {
      return Text(
        controller.currentPlaceName!,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }
    if (controller.isFetchingPlaceName) {
      return const SizedBox(
        height: 14,
        width: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white70,
        ),
      );
    }
    // Phase 3: when no prayer location has been resolved (fresh install or
    // permission denied), prompt the user to tap rather than showing nothing.
    if (controller.prayerLocation == null) {
      return Text(
        context.tr(
          bn: 'অবস্থান চালু করতে ট্যাপ করুন',
          en: 'Tap to enable location',
        ),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white54,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _fetchUserLocation(BuildContext context) async {
    final result = await controller.fetchUserLocation();
    if (result == null || !context.mounted) return;

    if (result.isSuccess) {
      final place = result.placeName;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              bn: 'লোকেশন: ${result.latitude}, ${result.longitude}${place != null ? ' ($place)' : ''}',
              en: 'Location: ${result.latitude}, ${result.longitude}${place != null ? ' ($place)' : ''}',
            ),
          ),
        ),
      );
      return;
    }

    switch (result.errorKind) {
      case HomeLocationFetchError.serviceDisabled:
        await _showLocationOffDialog(context);
        break;
      case HomeLocationFetchError.permissionDenied:
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                bn: 'অবস্থানের অনুমতি প্রয়োজন। অ্যাপ সেটিংসে চালু করুন।',
                en: 'Location permission is required. Enable it in Settings.',
              ),
            ),
            action: SnackBarAction(
              label: context.tr(bn: 'সেটিংস', en: 'Settings'),
              onPressed: () => controller.openLocationSettings(),
            ),
          ),
        );
        break;
      case HomeLocationFetchError.unknown:
      case null:
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                bn: 'অবস্থান পাওয়া যায়নি। আবার চেষ্টা করুন।',
                en: 'Could not get location. Please try again.',
              ),
            ),
          ),
        );
        break;
    }
  }

  /// Modal shown when the device's location services (GPS) are off. Carries a
  /// plain-language privacy declaration plus step-by-step guidance and a
  /// shortcut into the system location settings — mirrors the welcome screen.
  Future<void> _showLocationOffDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.location_off, color: Colors.orange, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr(
                    bn: 'লোকেশন (GPS) বন্ধ আছে',
                    en: 'Location (GPS) is turned off',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr(
                  bn: 'আপনার এলাকার সঠিক নামাজের সময় গণনা করতে ডিভাইসের লোকেশন '
                      'চালু করা প্রয়োজন। আপনার অবস্থান শুধু এই ডিভাইসেই নামাজের '
                      'সময় গণনায় ব্যবহৃত হয় — কখনো শেয়ার বা সার্ভারে সংরক্ষণ '
                      'করা হয় না।',
                  en: 'Turning on your device location lets us calculate '
                      'accurate prayer times for where you are. Your location '
                      'is used only on this device for prayer-time calculation '
                      '— it is never shared or stored on our servers.',
                ),
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(
                  bn: 'করণীয়:\n১. “লোকেশন সেটিংস খুলুন” চাপুন\n'
                      '২. লোকেশন / অবস্থান চালু করুন\n'
                      '৩. ফিরে এসে আবার অবস্থানে ট্যাপ করুন',
                  en: 'Steps:\n1. Tap “Open Location Settings”\n'
                      '2. Turn on Location\n'
                      '3. Come back and tap the location again',
                ),
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.tr(bn: 'বন্ধ করুন', en: 'Close')),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                controller.openLocationSettings();
              },
              icon: const Icon(Icons.location_on, size: 18),
              label: Text(
                context.tr(bn: 'লোকেশন সেটিংস খুলুন', en: 'Open Location Settings'),
              ),
            ),
          ],
        );
      },
    );
  }

  static const String _localMosqueValue = '__local_mosque__';

  String? _dropdownValueFor(HomeController controller) {
    if (controller.jamaatLocation.source == JamaatSource.local) {
      return _localMosqueValue;
    }
    return controller.selectedCity;
  }

  List<DropdownMenuItem<String>> _buildCityDropdownItems(BuildContext context) {
    final items = <DropdownMenuItem<String>>[];

    items.add(
      DropdownMenuItem(
        value: _localMosqueValue,
        child: Row(
          children: [
            const Icon(Icons.home_work, size: 15, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              context.tr(bn: 'লোকাল মসজিদ', en: 'Local Mosque'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );

    items.add(
      const DropdownMenuItem(
        enabled: false,
        value: null,
        child: Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            '🇧🇩 Bangladesh',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
    );
    for (final city in AppConstants.bangladeshCities) {
      items.add(
        DropdownMenuItem(
          value: city,
          child: Row(
            children: [
              const Icon(Icons.mosque, size: 15, color: Colors.white70),
              const SizedBox(width: 6),
              Text(city),
            ],
          ),
        ),
      );
    }

    items.add(
      const DropdownMenuItem(
        enabled: false,
        value: null,
        child: Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            '🇸🇦 Saudi Arabia',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
    );
    for (final city in AppConstants.saudiCities) {
      items.add(
        DropdownMenuItem(
          value: city,
          child: Row(
            children: [
              const Icon(Icons.mosque, size: 15, color: Colors.white70),
              const SizedBox(width: 6),
              Text(city),
            ],
          ),
        ),
      );
    }

    return items;
  }

  String _toHijriString(DateTime date) {
    final offset = controller.locationConfig?.country == Country.bangladesh
        ? controller.bangladeshHijriOffsetDays
        : 0;

    return HijriDateConverter.formatHijriDate(date, dayOffset: offset);
  }

  String _localizedDigitsForContext(BuildContext context, String value) {
    if (value == '-') return value;
    return LocaleDigits.localize(value, Localizations.localeOf(context));
  }
}
