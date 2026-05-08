import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:adhan_dart/adhan_dart.dart';
import '../core/constants.dart';
import '../services/prayer_time_engine.dart';
import '../utils/locale_digits.dart';

/// A self-contained countdown widget that updates every second.
/// Shows time remaining until the next prayer as a circular progress ring.
class PrayerCountdownWidget extends StatefulWidget {
  final Map<String, DateTime?> prayerTimes;
  final DateTime selectedDate;
  final Coordinates? coordinates;
  final CalculationParameters? calculationParams;
  final TextStyle? textStyle;
  final TextStyle? specialTextStyle;
  final bool isActive;

  const PrayerCountdownWidget({
    super.key,
    required this.prayerTimes,
    required this.selectedDate,
    this.coordinates,
    this.calculationParams,
    this.textStyle,
    this.specialTextStyle,
    this.isActive = true,
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
  DateTime? _cachedTomorrowFajrDay;
  double? _cachedTomorrowFajrLatitude;
  double? _cachedTomorrowFajrLongitude;
  CalculationParameters? _cachedTomorrowFajrParams;
  DateTime? _cachedTomorrowFajr;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safe place to read inherited widgets like Localizations.
    _calculateCountdown();
  }

  @override
  void didUpdateWidget(PrayerCountdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recalculate immediately when props change
    if (oldWidget.prayerTimes != widget.prayerTimes ||
        oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.coordinates != widget.coordinates ||
        oldWidget.calculationParams != widget.calculationParams) {
      _clearTomorrowFajrCache();
      _calculateCountdown();
    }
    if (oldWidget.isActive != widget.isActive) {
      _syncTimer();
    }
  }

  void _syncTimer() {
    if (!widget.isActive) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _startTimer();
  }

  void _startTimer() {
    if (_timer?.isActive ?? false) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _calculateCountdown();
      }
    });
  }

  void _clearTomorrowFajrCache() {
    _cachedTomorrowFajrDay = null;
    _cachedTomorrowFajrLatitude = null;
    _cachedTomorrowFajrLongitude = null;
    _cachedTomorrowFajrParams = null;
    _cachedTomorrowFajr = null;
  }

  bool get _isEnglish => Localizations.localeOf(context).languageCode == 'en';

  String _localizeDigits(String value) {
    return LocaleDigits.localize(value, Localizations.localeOf(context));
  }

  String _localizedPrayerName(String canonical) {
    if (_isEnglish) {
      return canonical;
    }
    switch (canonical) {
      case 'Fajr':
        return 'ফজর';
      case 'Sunrise':
        return 'সূর্যোদয়';
      case 'Dhuhr':
        return 'যোহর';
      case 'Asr':
        return 'আসর';
      case 'Maghrib':
        return 'মাগরিব';
      case 'Isha':
        return 'এশা';
      default:
        return canonical;
    }
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
    final localeCode = _isEnglish ? 'en' : 'bn';

    if (selectedDateOnly.isBefore(todayOnly)) {
      // Past date
      periodName = _isEnglish
          ? 'Viewing past date: ${DateFormat('dd MMM yyyy', localeCode).format(widget.selectedDate)}'
          : 'পূর্বের তারিখ দেখা হচ্ছে: ${DateFormat('dd MMM yyyy', localeCode).format(widget.selectedDate)}';
      periodName = _localizeDigits(periodName);
      isSpecial = true;
      progress = 0.0;
    } else if (selectedDateOnly.isAfter(todayOnly)) {
      // Future date
      periodName = _isEnglish
          ? 'Viewing future date: ${DateFormat('dd MMM yyyy', localeCode).format(widget.selectedDate)}'
          : 'ভবিষ্যতের তারিখ দেখা হচ্ছে: ${DateFormat('dd MMM yyyy', localeCode).format(widget.selectedDate)}';
      periodName = _localizeDigits(periodName);
      isSpecial = true;
      progress = 0.0;
    } else {
      // Today - show countdown with current period name
      final currentPeriod = PrayerTimeEngine.instance.getCurrentPrayerPeriod(
        times: widget.prayerTimes,
        now: now,
      );
      final timeToNext = PrayerTimeEngine.instance.getTimeToNextPrayerSafe(
        times: widget.prayerTimes,
        now: now,
        coordinates: widget.coordinates,
        params: widget.calculationParams,
      );
      progress = _calculateProgress(now);

      // Format as HH:MM:SS
      final hours = timeToNext.inHours;
      final minutes = timeToNext.inMinutes.remainder(60);
      final seconds = timeToNext.inSeconds.remainder(60);

      countdownTimeStr = timeToNext.isNegative
          ? '--:--:--'
          : '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      if (countdownTimeStr != '--:--:--') {
        countdownTimeStr = _localizeDigits(countdownTimeStr);
      }

      final localizedPeriod = _localizedPrayerName(currentPeriod);
      periodName = currentPeriod == 'Sunrise'
          ? (_isEnglish ? 'Coming Dhuhr' : 'আসছে যোহর')
          : (_isEnglish
                ? '$localizedPeriod time remaining'
                : '$localizedPeriod বাকি');
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

  double _calculateProgress(DateTime now) {
    final times = widget.prayerTimes;
    final order = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

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

      if (periodStart != null) {
        periodEnd = _tomorrowFajr(now);
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

  DateTime? _tomorrowFajr(DateTime now) {
    final coordinates = widget.coordinates;
    final params = widget.calculationParams;
    if (coordinates == null || params == null) {
      return null;
    }

    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    if (_cachedTomorrowFajrDay == tomorrow &&
        _cachedTomorrowFajrLatitude == coordinates.latitude &&
        _cachedTomorrowFajrLongitude == coordinates.longitude &&
        identical(_cachedTomorrowFajrParams, params)) {
      return _cachedTomorrowFajr;
    }

    final tomorrowPrayerTimes = PrayerTimes(
      coordinates: coordinates,
      date: tomorrow,
      calculationParameters: params,
      precision: true,
    );
    _cachedTomorrowFajrDay = tomorrow;
    _cachedTomorrowFajrLatitude = coordinates.latitude;
    _cachedTomorrowFajrLongitude = coordinates.longitude;
    _cachedTomorrowFajrParams = params;
    _cachedTomorrowFajr = tomorrowPrayerTimes.fajr;
    return _cachedTomorrowFajr;
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
        style:
            widget.specialTextStyle ??
            TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppConstants.brandGreenDark,
            ),
        textAlign: TextAlign.center,
      );
    }

    // Normal state: circular progress ring with countdown
    const double ringSize = 120.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.0,
                    child: Text(
                      _countdownTimeStr,
                      maxLines: 1,
                      softWrap: false,
                      style:
                          (widget.textStyle ??
                                  const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ))
                              .copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Prayer name label below the ring
        Text(
          _periodName,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
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
  static const double _strokeWidth = 10.0;

  const _CircularProgressPainter({
    required this.progress,
    required this.startColor,
    required this.endColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - _strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Draw track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = _strokeWidth
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
        ..strokeWidth = _strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor;
  }
}
