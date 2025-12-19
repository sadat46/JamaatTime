import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adhan_dart/adhan_dart.dart';

/// A self-contained countdown widget that updates every second.
/// Shows time remaining until the next prayer in HH:MM:SS format.
class PrayerCountdownWidget extends StatefulWidget {
  final Map<String, DateTime?> prayerTimes;
  final DateTime selectedDate;
  final Coordinates? coordinates;
  final CalculationParameters? calculationParams;
  final TextStyle? textStyle;
  final TextStyle? specialTextStyle;

  const PrayerCountdownWidget({
    super.key,
    required this.prayerTimes,
    required this.selectedDate,
    this.coordinates,
    this.calculationParams,
    this.textStyle,
    this.specialTextStyle,
  });

  @override
  State<PrayerCountdownWidget> createState() => _PrayerCountdownWidgetState();
}

class _PrayerCountdownWidgetState extends State<PrayerCountdownWidget> {
  Timer? _timer;
  String _countdownText = '';
  bool _isSpecialPrayer = false;

  // Default coordinates (Dhaka, Bangladesh)
  static const double _defaultLatitude = 23.8376;
  static const double _defaultLongitude = 90.2820;

  @override
  void initState() {
    super.initState();
    _calculateCountdown();
    _startTimer();
  }

  @override
  void didUpdateWidget(PrayerCountdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recalculate immediately when props change
    if (oldWidget.prayerTimes != widget.prayerTimes ||
        oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.coordinates != widget.coordinates) {
      _calculateCountdown();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _calculateCountdown();
      }
    });
  }

  void _calculateCountdown() {
    final now = DateTime.now();
    final selectedDateOnly = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    final todayOnly = DateTime(now.year, now.month, now.day);

    String text;
    bool isSpecial = false;

    if (selectedDateOnly.isBefore(todayOnly)) {
      // Past date
      text = 'Viewing past date: ${DateFormat('dd MMM yyyy').format(widget.selectedDate)}';
      isSpecial = true;
    } else if (selectedDateOnly.isAfter(todayOnly)) {
      // Future date
      text = 'Viewing future date: ${DateFormat('dd MMM yyyy').format(widget.selectedDate)}';
      isSpecial = true;
    } else {
      // Today - show countdown
      final currentPrayer = _getCurrentPrayerName(now);
      final timeToNext = _getTimeToNextPrayer(now);

      if (currentPrayer == 'Sunrise') {
        text = 'Coming Dahwa-e-kubrah';
        isSpecial = true;
      } else if (currentPrayer == 'Dahwah-e-kubrah') {
        text = 'Coming Dhuhr';
        isSpecial = true;
      } else {
        // Format as HH:MM:SS
        final hours = timeToNext.inHours;
        final minutes = timeToNext.inMinutes.remainder(60);
        final seconds = timeToNext.inSeconds.remainder(60);

        final countdown = timeToNext.isNegative
            ? '--:--:--'
            : '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        text = '$currentPrayer time remaining: $countdown';
        isSpecial = false;
      }
    }

    if (mounted) {
      setState(() {
        _countdownText = text;
        _isSpecialPrayer = isSpecial;
      });
    }
  }

  String _getCurrentPrayerName(DateTime now) {
    final times = widget.prayerTimes;
    final order = [
      'Fajr',
      'Sunrise',
      'Dahwah-e-kubrah',
      'Dhuhr',
      'Asr',
      'Maghrib',
      'Isha',
    ];

    // Find the next prayer (first prayer that hasn't passed yet)
    for (final name in order) {
      final t = times[name];
      if (t != null && now.isBefore(t)) {
        return name;
      }
    }

    // All prayers have passed, next is tomorrow's Fajr
    return 'Fajr';
  }

  Duration _getTimeToNextPrayer(DateTime now) {
    final times = widget.prayerTimes;
    final order = [
      'Fajr',
      'Sunrise',
      'Dahwah-e-kubrah',
      'Dhuhr',
      'Asr',
      'Maghrib',
      'Isha',
    ];

    for (final name in order) {
      final t = times[name];
      if (t != null && now.isBefore(t)) {
        return t.difference(now);
      }
    }

    // All prayers passed - calculate tomorrow's Fajr
    final tomorrow = now.add(const Duration(days: 1));
    final coords = widget.coordinates ??
        Coordinates(_defaultLatitude, _defaultLongitude);

    if (widget.calculationParams != null) {
      final tomorrowPrayerTimes = PrayerTimes(
        coordinates: coords,
        date: tomorrow,
        calculationParameters: widget.calculationParams!,
        precision: true,
      );
      final tomorrowFajr = tomorrowPrayerTimes.fajr;
      if (tomorrowFajr != null) {
        return tomorrowFajr.difference(now);
      }
    }

    return Duration.zero;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF1B5E20),
    );

    final specialStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF1B5E20),
    );

    return Text(
      _countdownText,
      style: _isSpecialPrayer
          ? (widget.specialTextStyle ?? specialStyle)
          : (widget.textStyle ?? defaultStyle),
    );
  }
}
