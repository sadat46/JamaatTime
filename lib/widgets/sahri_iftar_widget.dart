import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Widget to display Sahri and Iftar times with live countdown
class SahriIftarWidget extends StatefulWidget {
  final DateTime? fajrTime;
  final DateTime? maghribTime;

  const SahriIftarWidget({
    super.key,
    required this.fajrTime,
    required this.maghribTime,
  });

  @override
  State<SahriIftarWidget> createState() => _SahriIftarWidgetState();
}

class _SahriIftarWidgetState extends State<SahriIftarWidget> {
  Timer? _timer;
  String _sahriCountdown = '--:--:--';
  String _iftarCountdown = '--:--:--';

  @override
  void initState() {
    super.initState();
    _calculateCountdowns();
    _startTimer();
  }

  @override
  void didUpdateWidget(SahriIftarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fajrTime != widget.fajrTime ||
        oldWidget.maghribTime != widget.maghribTime) {
      _calculateCountdowns();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _calculateCountdowns();
      }
    });
  }

  void _calculateCountdowns() {
    final now = DateTime.now();
    String sahriCountdown = '--:--:--';
    String iftarCountdown = '--:--:--';

    // Calculate Sahri countdown (to Fajr)
    if (widget.fajrTime != null) {
      if (now.isBefore(widget.fajrTime!)) {
        // Before Fajr - show countdown to Sahri end
        final duration = widget.fajrTime!.difference(now);
        sahriCountdown = _formatDuration(duration);
      } else {
        // After Fajr - calculate next day's Fajr
        final tomorrow = now.add(const Duration(days: 1));
        // For now, approximate next Fajr as same time tomorrow
        // (In production, this should recalculate with proper prayer times)
        final fajrLocal = widget.fajrTime!.toLocal();
        final nextFajr = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          fajrLocal.hour,
          fajrLocal.minute,
          fajrLocal.second,
        );
        final duration = nextFajr.difference(now);
        sahriCountdown = _formatDuration(duration);
      }
    }

    // Calculate Iftar countdown (to Maghrib)
    if (widget.maghribTime != null) {
      if (now.isBefore(widget.maghribTime!)) {
        // Before Maghrib - show countdown to Iftar
        final duration = widget.maghribTime!.difference(now);
        iftarCountdown = _formatDuration(duration);
      } else {
        // After Maghrib - calculate next day's Maghrib
        final tomorrow = now.add(const Duration(days: 1));
        final maghribLocal = widget.maghribTime!.toLocal();
        final nextMaghrib = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          maghribLocal.hour,
          maghribLocal.minute,
          maghribLocal.second,
        );
        final duration = nextMaghrib.difference(now);
        iftarCountdown = _formatDuration(duration);
      }
    }

    if (mounted) {
      setState(() {
        _sahriCountdown = sahriCountdown;
        _iftarCountdown = iftarCountdown;
      });
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '--:--:--';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fajrTimeStr = widget.fajrTime != null
        ? DateFormat('HH:mm').format(widget.fajrTime!.toLocal())
        : '-';
    final maghribTimeStr = widget.maghribTime != null
        ? DateFormat('HH:mm').format(widget.maghribTime!.toLocal())
        : '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0),
          child: Text(
            'Sahri & Iftar Times',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(3),
          },
          children: [
            // Header Row
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.orange.shade900
                    : Colors.orange.shade700,
              ),
              children: const [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Name',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Time',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Remaining Time',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            // Sahri Row
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.orange.shade900.withValues(alpha: 0.2)
                    : Colors.orange.shade50,
              ),
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Sahri Ends'),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: Text(
                      fajrTimeStr,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: Text(
                      _sahriCountdown,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Iftar Row
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.orange.shade900.withValues(alpha: 0.2)
                    : Colors.orange.shade50,
              ),
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Iftar Begins'),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: Text(
                      maghribTimeStr,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Center(
                    child: Text(
                      _iftarCountdown,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
