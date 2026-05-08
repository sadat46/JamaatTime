import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/app_theme_tokens.dart';
import '../../../core/constants.dart';
import '../../../core/locale_text.dart';
import '../../../models/location_config.dart';
import '../../../services/hijri_date_converter.dart';
import '../../../utils/bangla_calendar.dart';
import '../../../utils/locale_digits.dart';
import '../../../widgets/live_clock_widget.dart';
import '../../../widgets/prayer_countdown_widget.dart';
import '../home_controller.dart';
import 'notice_action_button.dart';

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
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final localeCode = Localizations.localeOf(context).languageCode == 'en'
            ? 'en'
            : 'bn';
        final dateStr = _localizedDigitsForContext(
          context,
          DateFormat(
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
          dateStr: dateStr,
          hijriStr: hijriStr,
          banglaDateStr: banglaDateStr,
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required String dateStr,
    required String hijriStr,
    required String banglaDateStr,
  }) {
    final topPadding = MediaQuery.of(context).viewPadding.top;
    final maxHeaderWidth = pageConstraints.maxWidth < 600
        ? pageConstraints.maxWidth
        : 600.0;
    final horizontalPadding = pageConstraints.maxWidth < 400 ? 16.0 : 20.0;
    final countdownGap = pageConstraints.maxWidth < 400 ? 16.0 : 28.0;

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
          constraints: BoxConstraints(maxWidth: maxHeaderWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              topPadding + 10,
              horizontalPadding,
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
                      horizontal: pageConstraints.maxWidth < 400 ? 14.0 : 18.0,
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
                        SizedBox(width: countdownGap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (controller.locationConfig == null ||
                                  controller.locationConfig!.jamaatSource !=
                                      JamaatSource.none)
                                DropdownButton<String>(
                                  isExpanded: true,
                                  value: controller.selectedCity,
                                  items: _buildCityDropdownItems(),
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
                                    if (value == null ||
                                        value == controller.selectedCity) {
                                      return;
                                    }
                                    await controller.selectCity(value);
                                  },
                                ),
                              if (controller.locationConfig != null &&
                                  controller.locationConfig!.jamaatSource ==
                                      JamaatSource.none)
                                Text(
                                  controller.currentPlaceName ??
                                      context.tr(
                                        bn: 'সনাক্ত করা হচ্ছে...',
                                        en: 'Detecting...',
                                      ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
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
                                      child: controller.currentPlaceName != null
                                          ? Text(
                                              controller.currentPlaceName!,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            )
                                          : controller.isFetchingPlaceName
                                          ? const SizedBox(
                                              height: 14,
                                              width: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white70,
                                              ),
                                            )
                                          : const SizedBox.shrink(),
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
                              if (controller.locationConfig != null &&
                                  controller.locationConfig!.jamaatSource ==
                                      JamaatSource.none &&
                                  !controller.isLoadingJamaat &&
                                  controller.jamaatError == null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          context.tr(
                                            bn: 'GPS মোড: জামাত সময় নেই',
                                            en: 'GPS Mode: No jamaat times',
                                          ),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white70,
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: ${result.error}')),
      );
    }
  }

  List<DropdownMenuItem<String>> _buildCityDropdownItems() {
    final items = <DropdownMenuItem<String>>[];

    items.add(
      const DropdownMenuItem(
        enabled: false,
        value: null,
        child: Text(
          '🇧🇩 Bangladesh',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
