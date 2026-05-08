import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/locale_digits.dart';

/// A self-contained clock widget that updates every 60 seconds.
/// This widget owns its own timer and does not depend on parent state.
class LiveClockWidget extends StatefulWidget {
  final TextStyle? textStyle;
  final String format;
  final bool isActive;

  const LiveClockWidget({
    super.key,
    this.textStyle,
    this.format = 'HH:mm',
    this.isActive = true,
  });

  @override
  State<LiveClockWidget> createState() => _LiveClockWidgetState();
}

class _LiveClockWidgetState extends State<LiveClockWidget> {
  Timer? _timer;
  Timer? _syncTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _syncClockTimer();
  }

  @override
  void didUpdateWidget(covariant LiveClockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive ||
        oldWidget.format != widget.format) {
      _syncClockTimer();
    }
  }

  void _syncClockTimer() {
    _timer?.cancel();
    _timer = null;
    _syncTimer?.cancel();
    _syncTimer = null;

    if (!widget.isActive) {
      return;
    }

    _currentTime = DateTime.now();

    // Calculate delay to sync with the start of the next minute
    final now = DateTime.now();
    final secondsUntilNextMinute = 60 - now.second;

    // First, set a one-time timer to sync to the minute boundary
    _syncTimer = Timer(Duration(seconds: secondsUntilNextMinute), () {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
        // Then start the periodic 60-second timer
        _startPeriodicTimer();
      }
    });
  }

  void _startPeriodicTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final timeStr = LocaleDigits.localize(
      DateFormat(widget.format).format(_currentTime),
      locale,
    );

    return Text(
      timeStr,
      style:
          widget.textStyle ??
          Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}
