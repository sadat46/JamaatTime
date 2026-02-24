import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/screen_awake_service.dart';

enum SahriIftarType { sahri, iftar }

class _SahriIftarCountdownLogic {
  static const String unavailableCountdown = '--:--:--';

  static String formatTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return DateFormat('HH:mm').format(value.toLocal());
  }

  static String calculateCountdown(DateTime? targetTime, DateTime now) {
    if (targetTime == null) {
      return unavailableCountdown;
    }

    final DateTime target;
    if (now.isBefore(targetTime)) {
      target = targetTime;
    } else {
      final tomorrow = now.add(const Duration(days: 1));
      final localTarget = targetTime.toLocal();
      target = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        localTarget.hour,
        localTarget.minute,
        localTarget.second,
      );
    }

    final duration = target.difference(now);
    return _formatDuration(duration);
  }

  static String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return unavailableCountdown;
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

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
  String _sahriCountdown = _SahriIftarCountdownLogic.unavailableCountdown;
  String _iftarCountdown = _SahriIftarCountdownLogic.unavailableCountdown;

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
    final sahriCountdown = _SahriIftarCountdownLogic.calculateCountdown(
      widget.fajrTime,
      now,
    );
    final iftarCountdown = _SahriIftarCountdownLogic.calculateCountdown(
      widget.maghribTime,
      now,
    );

    if (mounted) {
      setState(() {
        _sahriCountdown = sahriCountdown;
        _iftarCountdown = iftarCountdown;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fajrTimeStr = _SahriIftarCountdownLogic.formatTime(widget.fajrTime);
    final maghribTimeStr = _SahriIftarCountdownLogic.formatTime(
      widget.maghribTime,
    );

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
        _SahriIftarCard(
          key: const Key('sahri-card'),
          type: SahriIftarType.sahri,
          title: 'Sahri Ends',
          timeText: fajrTimeStr,
          countdownText: _sahriCountdown,
          onTap: () => _openFullscreen(SahriIftarType.sahri),
        ),
        const SizedBox(height: 12),
        _SahriIftarCard(
          key: const Key('iftar-card'),
          type: SahriIftarType.iftar,
          title: 'Iftar Begins',
          timeText: maghribTimeStr,
          countdownText: _iftarCountdown,
          onTap: () => _openFullscreen(SahriIftarType.iftar),
        ),
      ],
    );
  }

  void _openFullscreen(SahriIftarType type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SahriIftarFullscreenPage(
          type: type,
          fajrTime: widget.fajrTime,
          maghribTime: widget.maghribTime,
        ),
      ),
    );
  }
}

class _SahriIftarCard extends StatelessWidget {
  final SahriIftarType type;
  final String title;
  final String timeText;
  final String countdownText;
  final VoidCallback onTap;

  const _SahriIftarCard({
    super.key,
    required this.type,
    required this.title,
    required this.timeText,
    required this.countdownText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSahri = type == SahriIftarType.sahri;
    final Color accentColor = isSahri
        ? const Color(0xFFEF6C00)
        : const Color(0xFFD84315);
    final IconData icon = isSahri ? Icons.nightlight_round : Icons.wb_sunny;
    final Color cardColor = Theme.of(context).brightness == Brightness.dark
        ? accentColor.withValues(alpha: 0.2)
        : accentColor.withValues(alpha: 0.08);

    return Card(
      elevation: 1,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Time: $timeText',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Remaining',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    countdownText,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SahriIftarFullscreenPage extends StatefulWidget {
  final SahriIftarType type;
  final DateTime? fajrTime;
  final DateTime? maghribTime;

  const SahriIftarFullscreenPage({
    super.key,
    required this.type,
    required this.fajrTime,
    required this.maghribTime,
  });

  @override
  State<SahriIftarFullscreenPage> createState() =>
      _SahriIftarFullscreenPageState();
}

class _SahriIftarFullscreenPageState extends State<SahriIftarFullscreenPage>
    with WidgetsBindingObserver {
  Timer? _timer;
  String _countdown = _SahriIftarCountdownLogic.unavailableCountdown;

  DateTime? get _activeTime => widget.type == SahriIftarType.sahri
      ? widget.fajrTime
      : widget.maghribTime;

  bool get _isSahri => widget.type == SahriIftarType.sahri;

  String get _title => _isSahri ? 'Sahri Ends' : 'Iftar Begins';

  String get _header => _isSahri ? 'Sahri Focus' : 'Iftar Focus';

  Color get _accentColor =>
      _isSahri ? const Color(0xFFEF6C00) : const Color(0xFFD84315);

  IconData get _icon => _isSahri ? Icons.nightlight_round : Icons.wb_sunny;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_setWakeLock(enabled: true));
    _calculateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _calculateCountdown();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_setWakeLock(enabled: true));
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_setWakeLock(enabled: false));
    }
  }

  Future<void> _setWakeLock({required bool enabled}) async {
    await ScreenAwakeService.setEnabled(enabled);
  }

  void _calculateCountdown() {
    final now = DateTime.now();
    setState(() {
      _countdown = _SahriIftarCountdownLogic.calculateCountdown(
        _activeTime,
        now,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    unawaited(_setWakeLock(enabled: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeText = _SahriIftarCountdownLogic.formatTime(_activeTime);
    final Color cardColor = Theme.of(context).brightness == Brightness.dark
        ? _accentColor.withValues(alpha: 0.24)
        : _accentColor.withValues(alpha: 0.08);

    return Scaffold(
      appBar: AppBar(
        title: Text(_header),
        actions: [
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox.expand(
            child: Card(
              key: Key('${_isSahri ? 'sahri' : 'iftar'}-fullscreen'),
              elevation: 2,
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _accentColor.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_icon, size: 40, color: _accentColor),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      timeText,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _countdown,
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _accentColor,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Remaining Time',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
