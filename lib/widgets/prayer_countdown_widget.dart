import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adhan_dart/adhan_dart.dart';
import '../core/constants.dart';

/// A self-contained countdown widget that updates every second.
/// Shows time remaining until the next prayer as a circular progress ring.
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
  String _periodName = '';
  String _countdownTimeStr = '';
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

    String periodName;
    String countdownTimeStr = '';
    bool isSpecial = false;
    double progress = 0.0;

    if (selectedDateOnly.isBefore(todayOnly)) {
      // Past date
      periodName = 'Viewing past date: ${DateFormat('dd MMM yyyy').format(widget.selectedDate)}';
      isSpecial = true;
      progress = 0.0;
    } else if (selectedDateOnly.isAfter(todayOnly)) {
      // Future date
      periodName = 'Viewing future date: ${DateFormat('dd MMM yyyy').format(widget.selectedDate)}';
      isSpecial = true;
      progress = 0.0;
    } else {
      // Today - show countdown with current period name
      final currentPeriod = _getCurrentPrayerPeriodName(now);
      final timeToNext = _getTimeToNextPrayer(now);
      progress = _calculateProgress(now);

      // Format as HH:MM:SS
      final hours = timeToNext.inHours;
      final minutes = timeToNext.inMinutes.remainder(60);
      final seconds = timeToNext.inSeconds.remainder(60);

      countdownTimeStr = timeToNext.isNegative
          ? '--:--:--'
          : '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

      periodName = currentPeriod == 'Sunrise'
          ? 'Coming Dhuhr'
          : '$currentPeriod time remaining';
      isSpecial = false;
    }

    if (mounted) {
      setState(() {
        _periodName = periodName;
        _countdownTimeStr = countdownTimeStr;
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
    if (_isSpecialPrayer) {
      // Special state (past/future date): text-only display
      return Text(
        _periodName,
        style: widget.specialTextStyle ?? TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppConstants.brandGreenDark,
        ),
        textAlign: TextAlign.center,
      );
    }

    // Normal state: circular progress ring with countdown
    const double ringSize = 140.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Prayer name label above the ring
        Text(
          _periodName,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        // Circular ring
        SizedBox(
          width: ringSize,
          height: ringSize,
          child: CustomPaint(
            painter: _CircularProgressPainter(
              progress: _progressValue,
              startColor: const Color(0xFF69F0AE),
              endColor: Colors.white,
              trackColor: Colors.white.withValues(alpha: 0.15),
            ),
            child: Center(
              child: Text(
                _countdownTimeStr,
                style: (widget.textStyle ?? const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                )).copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for a circular progress ring with gradient stroke.
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color startColor;
  final Color endColor;
  final Color trackColor;
  final double strokeWidth;

  const _CircularProgressPainter({
    required this.progress,
    required this.startColor,
    required this.endColor,
    required this.trackColor,
    this.strokeWidth = 10.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Draw track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Draw progress arc with gradient
    if (progress > 0.005) {
      final sweepAngle = 2 * math.pi * progress;
      final gradient = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + sweepAngle,
        colors: [startColor, endColor],
        tileMode: TileMode.clamp,
      );
      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor;
  }
}
