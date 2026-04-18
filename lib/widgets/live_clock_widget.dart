import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/locale_digits.dart';

/// A self-contained clock widget that updates every 60 seconds.
/// This widget owns its own timer and does not depend on parent state.
class LiveClockWidget extends StatefulWidget {
  final TextStyle? textStyle;
  final String format;

  const LiveClockWidget({
    super.key,
    this.textStyle,
    this.format = 'HH:mm',
  });

  @override
  State<LiveClockWidget> createState() => _LiveClockWidgetState();
}

class _LiveClockWidgetState extends State<LiveClockWidget> {
  Timer? _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();

    // Calculate delay to sync with the start of the next minute
    final now = DateTime.now();
    final secondsUntilNextMinute = 60 - now.second;

    // First, set a one-time timer to sync to the minute boundary
    Future.delayed(Duration(seconds: secondsUntilNextMinute), () {
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
      style: widget.textStyle ??
          Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
    );
  }
}
