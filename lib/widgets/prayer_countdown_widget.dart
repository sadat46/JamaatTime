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
  double _progressValue = 0.0;

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
    double progress = 0.0;

    if (selectedDateOnly.isBefore(todayOnly)) {
      // Past date
      text = 'Viewing past date: ${DateFormat('dd MMM yyyy').format(widget.selectedDate)}';
      isSpecial = true;
      progress = 0.0;
    } else if (selectedDateOnly.isAfter(todayOnly)) {
      // Future date
      text = 'Viewing future date: ${DateFormat('dd MMM yyyy').format(widget.selectedDate)}';
      isSpecial = true;
      progress = 0.0;
    } else {
      // Today - show countdown with current period name
      final currentPeriod = _getCurrentPrayerPeriodName(now);
      final timeToNext = _getTimeToNextPrayer(now);
      progress = _calculateProgress(now);

      if (currentPeriod == 'Sunrise') {
        text = 'Coming Dahwa-e-kubrah';
        isSpecial = true;
      } else if (currentPeriod == 'Dahwah-e-kubrah') {
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

        text = '$currentPeriod time remaining: $countdown';
        isSpecial = false;
      }
    }

    if (mounted) {
      setState(() {
        _countdownText = text;
        _isSpecialPrayer = isSpecial;
        _progressValue = progress;
      });
    }
  }

  String _getCurrentPrayerPeriodName(DateTime now) {
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

    // Find which period we're currently in
    String currentPeriod = 'Isha'; // Default (between midnight and Fajr)

    for (int i = 0; i < order.length; i++) {
      final t = times[order[i]];
      if (t != null) {
        if (now.isBefore(t)) {
          // We haven't reached this prayer yet, so we're in the previous period
          return i > 0 ? order[i - 1] : 'Isha';
        }
        // We've passed this prayer, update current period
        currentPeriod = order[i];
      }
    }

    return currentPeriod; // We've passed all prayers (Isha period)
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

  double _calculateProgress(DateTime now) {
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

    DateTime? periodStart;
    DateTime? periodEnd;

    // Find current period boundaries
    for (int i = 0; i < order.length; i++) {
      final t = times[order[i]];
      if (t != null && now.isBefore(t)) {
        if (i > 0) {
          periodStart = times[order[i - 1]];
          periodEnd = t;
        } else {
          // Before first prayer - return 0 for simplicity
          return 0.0;
        }
        break;
      }
    }

    // After all prayers - we're in Isha period
    if (periodStart == null || periodEnd == null) {
      periodStart = times['Isha'];

      // Get tomorrow's Fajr
      if (periodStart != null && widget.coordinates != null && widget.calculationParams != null) {
        final tomorrow = now.add(const Duration(days: 1));
        final tomorrowPrayerTimes = PrayerTimes(
          coordinates: widget.coordinates!,
          date: tomorrow,
          calculationParameters: widget.calculationParams!,
          precision: true,
        );
        periodEnd = tomorrowPrayerTimes.fajr;
      }
    }

    // Calculate progress
    if (periodStart != null && periodEnd != null) {
      final totalDuration = periodEnd.difference(periodStart).inMilliseconds;
      final elapsedDuration = now.difference(periodStart).inMilliseconds;

      if (totalDuration > 0) {
        final progress = elapsedDuration / totalDuration;
        return progress.clamp(0.0, 1.0);
      }
    }

    return 0.0;
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

    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Countdown text
          Text(
            _countdownText,
            style: _isSpecialPrayer
                ? (widget.specialTextStyle ?? specialStyle)
                : (widget.textStyle ?? defaultStyle),
          ),

          // Progress bar (only for normal prayers, not special "Coming..." messages)
          if (!_isSpecialPrayer) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _progressValue,
              backgroundColor: const Color(0xFFE0E0E0),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF1B5E20),
              ),
              minHeight: 8,
            ),
          ],
        ],
      ),
    );
  }
}
