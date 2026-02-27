import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';
import '../services/screen_awake_service.dart';
import 'shared_ui_widgets.dart';

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
    final duration = remainingDuration(targetTime, now);
    if (duration == null) {
      return unavailableCountdown;
    }
    return _formatDuration(duration);
  }

  static Duration? remainingDuration(DateTime? targetTime, DateTime now) {
    final target = resolveNextOccurrence(targetTime, now);
    if (target == null) {
      return null;
    }

    final duration = target.difference(now);
    if (duration.isNegative) {
      return null;
    }

    return duration;
  }

  static DateTime? resolveNextOccurrence(DateTime? targetTime, DateTime now) {
    if (targetTime == null) {
      return null;
    }

    if (now.isBefore(targetTime)) {
      return targetTime;
    }

    final tomorrow = now.add(const Duration(days: 1));
    final localTarget = targetTime.toLocal();
    return DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      localTarget.hour,
      localTarget.minute,
      localTarget.second,
    );
  }

  static const Duration gracePeriod = Duration(minutes: 3);
  static const Duration warningThreshold = Duration(minutes: 2);

  /// Returns elapsed duration since [targetTime] if within the 3-minute
  /// grace period. Returns null if not in grace period.
  static Duration? graceElapsed(DateTime? targetTime, DateTime now) {
    if (targetTime == null) return null;
    final target = targetTime.toLocal();
    if (now.isBefore(target)) return null;
    final elapsed = now.difference(target);
    if (elapsed > gracePeriod) return null;
    return elapsed;
  }

  /// Formats an elapsed duration as forward-counting MM:SS or HH:MM:SS.
  static String formatElapsed(Duration elapsed) {
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60);
    final s = elapsed.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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

class _SahriIftarVisualSpec {
  final List<Color> panelColors;
  final List<Color> ambientColors;
  final Color accent;
  final Color primaryText;
  final Color secondaryText;
  final Color border;
  final Color glassTint;
  final Color glow;
  final Color ringTrack;

  const _SahriIftarVisualSpec({
    required this.panelColors,
    required this.ambientColors,
    required this.accent,
    required this.primaryText,
    required this.secondaryText,
    required this.border,
    required this.glassTint,
    required this.glow,
    required this.ringTrack,
  });

  static const _SahriIftarVisualSpec _sahriLight = _SahriIftarVisualSpec(
    panelColors: [Color(0xFFEFF8F1), Color(0xFFDFF0E4)],
    ambientColors: [Color(0xFFF5FBF6), Color(0xFFEAF6EE)],
    accent: AppConstants.brandGreenDark,
    primaryText: Color(0xFF1F2E24),
    secondaryText: Color(0xFF516659),
    border: Color(0x85FFFFFF),
    glassTint: Color(0x26FFFFFF),
    glow: Color(0x33145A32),
    ringTrack: Color(0x24145A32),
  );

  static const _SahriIftarVisualSpec _iftarLight = _SahriIftarVisualSpec(
    panelColors: [Color(0xFFEAF5EC), Color(0xFFD6EAD9)],
    ambientColors: [Color(0xFFF2FAF4), Color(0xFFE6F3E9)],
    accent: AppConstants.brandGreen,
    primaryText: Color(0xFF1E2C22),
    secondaryText: Color(0xFF4F6458),
    border: Color(0x7AFFFFFF),
    glassTint: Color(0x24FFFFFF),
    glow: Color(0x33388E3C),
    ringTrack: Color(0x26388E3C),
  );

  static const _SahriIftarVisualSpec _sahriDark = _SahriIftarVisualSpec(
    panelColors: [Color(0xFF173325), Color(0xFF10261B)],
    ambientColors: [Color(0xFF0F2319), Color(0xFF09180F)],
    accent: Color(0xFF8DD79A),
    primaryText: Color(0xFFE7F5EB),
    secondaryText: Color(0xFFC0DCC8),
    border: Color(0x405EDB7A),
    glassTint: Color(0x1A1A3A2A),
    glow: Color(0x338DD79A),
    ringTrack: Color(0x288DD79A),
  );

  static const _SahriIftarVisualSpec _iftarDark = _SahriIftarVisualSpec(
    panelColors: [Color(0xFF1E3A2B), Color(0xFF14291E)],
    ambientColors: [Color(0xFF12261C), Color(0xFF0A1812)],
    accent: Color(0xFFA5E7AF),
    primaryText: Color(0xFFEAF7EE),
    secondaryText: Color(0xFFC7E2CE),
    border: Color(0x3F73E08A),
    glassTint: Color(0x1A1F3F2E),
    glow: Color(0x30A5E7AF),
    ringTrack: Color(0x28A5E7AF),
  );

  static _SahriIftarVisualSpec from({
    required SahriIftarType type,
    required Brightness brightness,
  }) {
    if (brightness == Brightness.dark) {
      return type == SahriIftarType.sahri ? _sahriDark : _iftarDark;
    }

    return type == SahriIftarType.sahri ? _sahriLight : _iftarLight;
  }

  LinearGradient get panelGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: panelColors,
  );

  LinearGradient get ambientGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: ambientColors,
  );
}

/// Widget to display Sahri and Iftar times with live countdown
class SahriIftarWidget extends StatefulWidget {
  final DateTime? fajrTime;
  final DateTime? maghribTime;
  final bool showTitle;

  const SahriIftarWidget({
    super.key,
    required this.fajrTime,
    required this.maghribTime,
    this.showTitle = false,
  });

  @override
  State<SahriIftarWidget> createState() => _SahriIftarWidgetState();
}

class _SahriIftarWidgetState extends State<SahriIftarWidget> {
  Timer? _timer;
  String _sahriCountdown = _SahriIftarCountdownLogic.unavailableCountdown;
  String _iftarCountdown = _SahriIftarCountdownLogic.unavailableCountdown;
  bool _sehriInGrace = false;
  bool _iftarInGrace = false;
  bool _animateIn = false;

  @override
  void initState() {
    super.initState();
    _calculateCountdowns();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _animateIn = true;
      });
    });
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
    final sahriGrace = _SahriIftarCountdownLogic.graceElapsed(
      widget.fajrTime,
      now,
    );
    final iftarGrace = _SahriIftarCountdownLogic.graceElapsed(
      widget.maghribTime,
      now,
    );

    if (mounted) {
      setState(() {
        _sehriInGrace = sahriGrace != null;
        if (sahriGrace != null) {
          _sahriCountdown = _SahriIftarCountdownLogic.formatElapsed(sahriGrace);
        } else {
          _sahriCountdown = _SahriIftarCountdownLogic.calculateCountdown(
            widget.fajrTime,
            now,
          );
        }
        _iftarInGrace = iftarGrace != null;
        if (iftarGrace != null) {
          _iftarCountdown = _SahriIftarCountdownLogic.formatElapsed(iftarGrace);
        } else {
          _iftarCountdown = _SahriIftarCountdownLogic.calculateCountdown(
            widget.maghribTime,
            now,
          );
        }
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
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final Duration entryDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 360);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTitle)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0),
            child: Text(
              'Sahri & Iftar Times',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppConstants.brandGreenDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        _buildCardEntry(
          duration: entryDuration,
          child: _SahriIftarCard(
            key: const Key('sahri-card'),
            type: SahriIftarType.sahri,
            title: 'Sahri Ends',
            timeText: fajrTimeStr,
            countdownText: _sahriCountdown,
            onTap: () => _openFullscreen(SahriIftarType.sahri),
            inGrace: _sehriInGrace,
          ),
        ),
        const SizedBox(height: 12),
        _buildCardEntry(
          duration: entryDuration,
          child: _SahriIftarCard(
            key: const Key('iftar-card'),
            type: SahriIftarType.iftar,
            title: 'Iftar Begins',
            timeText: maghribTimeStr,
            countdownText: _iftarCountdown,
            onTap: () => _openFullscreen(SahriIftarType.iftar),
            inGrace: _iftarInGrace,
          ),
        ),
      ],
    );
  }

  Widget _buildCardEntry({required Widget child, required Duration duration}) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: _animateIn ? 1 : 0),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final offsetY = (1 - value) * 8;
        final scale = 0.985 + (value * 0.015);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, offsetY),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: child,
    );
  }

  void _openFullscreen(SahriIftarType type) {
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final Duration duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 260);

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: duration,
        reverseTransitionDuration: duration,
        pageBuilder: (context, animation, secondaryAnimation) {
          return SahriIftarFullscreenPage(
            type: type,
            fajrTime: widget.fajrTime,
            maghribTime: widget.maghribTime,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
              child: child,
            ),
          );
        },
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
  final bool inGrace;

  const _SahriIftarCard({
    super.key,
    required this.type,
    required this.title,
    required this.timeText,
    required this.countdownText,
    required this.onTap,
    this.inGrace = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSahri = type == SahriIftarType.sahri;
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    final double cardHeight = (100 * textScale.clamp(1.0, 1.2)).toDouble();
    final spec = _SahriIftarVisualSpec.from(
      type: type,
      brightness: Theme.of(context).brightness,
    );
    final LinearGradient cardGradient = isDarkMode
        ? spec.panelGradient
        : LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.white,
              Colors.white,
              isSahri ? const Color(0xFFC6EBC8) : const Color(0xFFB8E4BB),
            ],
            stops: const [0.0, 0.68, 1.0],
          );

    final TextStyle countdownStyle =
        Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: spec.accent,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: 1.0,
          height: 1,
        ) ??
        TextStyle(
          color: spec.accent,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: 1,
          height: 1,
        );

    return Semantics(
      button: true,
      label: isSahri ? 'Sahri focus card' : 'Iftar focus card',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: SizedBox(
            height: cardHeight,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: cardGradient,
                border: Border.all(color: spec.border),
                boxShadow: [
                  BoxShadow(
                    color: spec.glow,
                    blurRadius: 18,
                    spreadRadius: 0.3,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    Positioned(
                      right: -24,
                      top: -24,
                      child: Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: spec.accent.withValues(alpha: 0.09),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -10,
                      bottom: -14,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: spec.primaryText,
                                        fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.72),
                                  border: Border.all(
                                    color: spec.accent.withValues(alpha: 0.24),
                                  ),
                                ),
                                child: Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 16,
                                  color: spec.accent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InfoChip(
                                icon: Icons.schedule_outlined,
                                label:
                                    '${isSahri ? 'Ends at' : 'Begins at'} $timeText',
                                accent: spec.accent,
                                textColor: spec.primaryText,
                                fill: spec.glassTint.withValues(alpha: 0.85),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                iconSize: 12,
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: spec.primaryText,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: reduceMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 180),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                                child: FittedBox(
                                  key: ValueKey(countdownText),
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    countdownText,
                                    style: countdownStyle,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  inGrace
                                      ? (isSahri
                                          ? 'Sehri time finished'
                                          : 'Iftar time started')
                                      : 'Remaining Time',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: inGrace
                                            ? Colors.amber.shade700
                                            : spec.secondaryText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InfoChip(
                                icon: Icons.open_in_full_rounded,
                                label: 'Focus',
                                accent: spec.accent,
                                textColor: spec.secondaryText,
                                fill: spec.glassTint.withValues(alpha: 0.75),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                iconSize: 12,
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: spec.secondaryText,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ],
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
    with WidgetsBindingObserver, TickerProviderStateMixin {
  Timer? _timer;
  String _countdown = _SahriIftarCountdownLogic.unavailableCountdown;
  bool _inGrace = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  DateTime? get _activeTime => widget.type == SahriIftarType.sahri
      ? widget.fajrTime
      : widget.maghribTime;

  bool get _isSahri => widget.type == SahriIftarType.sahri;

  String get _title => _isSahri ? 'Sahri Ends' : 'Iftar Begins';

  String get _header => _isSahri ? 'Sahri Focus' : 'Iftar Focus';

  IconData get _icon => _isSahri ? Icons.nightlight_round : Icons.wb_sunny;

  double _countdownProgress(DateTime now) {
    final graceTime = _SahriIftarCountdownLogic.graceElapsed(_activeTime, now);
    if (graceTime != null) {
      return graceTime.inSeconds /
          _SahriIftarCountdownLogic.gracePeriod.inSeconds;
    }

    final remaining = _SahriIftarCountdownLogic.remainingDuration(
      _activeTime,
      now,
    );
    if (remaining == null) {
      return 0;
    }

    const int totalSeconds = 24 * 60 * 60;
    final elapsed = (totalSeconds - remaining.inSeconds).clamp(0, totalSeconds);
    return elapsed / totalSeconds;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
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
    final elapsed = _SahriIftarCountdownLogic.graceElapsed(_activeTime, now);
    final newInGrace = elapsed != null;

    setState(() {
      _inGrace = newInGrace;
      if (elapsed != null) {
        _countdown = _SahriIftarCountdownLogic.formatElapsed(elapsed);
      } else {
        _countdown = _SahriIftarCountdownLogic.calculateCountdown(
          _activeTime,
          now,
        );
      }
    });

    final remaining = _SahriIftarCountdownLogic.remainingDuration(
      _activeTime,
      now,
    );
    final shouldPulse = !newInGrace &&
        remaining != null &&
        remaining <= _SahriIftarCountdownLogic.warningThreshold;

    if (shouldPulse && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!shouldPulse && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pulseController.dispose();
    unawaited(_setWakeLock(enabled: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final now = DateTime.now();
    final progress = _countdownProgress(now);
    final timeText = _SahriIftarCountdownLogic.formatTime(_activeTime);
    final spec = _SahriIftarVisualSpec.from(
      type: widget.type,
      brightness: Theme.of(context).brightness,
    );

    final countdownBaseStyle =
        Theme.of(context).textTheme.displaySmall?.copyWith(
          color: spec.accent,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: 1.2,
        );

    return Scaffold(
      backgroundColor: spec.ambientColors.last,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: spec.primaryText,
        title: Text(_header),
        actions: [
          IconButton(
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: spec.ambientGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  key: Key('${_isSahri ? 'sahri' : 'iftar'}-fullscreen'),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: spec.panelGradient,
                    border: Border.all(color: spec.border),
                    boxShadow: [
                      BoxShadow(
                        color: spec.glow,
                        blurRadius: 28,
                        spreadRadius: 0.6,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Stack(
                      children: [
                        Positioned(
                          left: -40,
                          top: -40,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: spec.accent.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -24,
                          bottom: -34,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 26,
                            vertical: 30,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double ringSize =
                                  (constraints.maxHeight * 0.44)
                                      .clamp(170.0, 250.0)
                                      .toDouble();

                              return SingleChildScrollView(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AccentIconBadge(
                                        icon: _icon,
                                        accent: spec.accent,
                                        tint: spec.glassTint,
                                        size: 74,
                                        iconSize: 38,
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        _title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              color: spec.primaryText,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 18),
                                      AnimatedBuilder(
                                        animation: _pulseAnim,
                                        builder: (context, _) {
                                          final pulseVal = _pulseAnim.value;
                                          final ringStroke =
                                              10.0 + pulseVal * 4.0;
                                          final pulseColor = Color.lerp(
                                            spec.accent,
                                            Colors.redAccent,
                                            pulseVal,
                                          )!;
                                          final isWarning =
                                              _pulseController.isAnimating;
                                          final countdownStyle =
                                              countdownBaseStyle?.copyWith(
                                                color: isWarning
                                                    ? pulseColor
                                                    : spec.accent,
                                                shadows: isWarning
                                                    ? [
                                                        Shadow(
                                                          color: Colors.redAccent
                                                              .withValues(
                                                                alpha: 0.7 *
                                                                    pulseVal,
                                                              ),
                                                          blurRadius:
                                                              12 * pulseVal,
                                                        ),
                                                      ]
                                                    : null,
                                              );
                                          return SizedBox(
                                            width: ringSize,
                                            height: ringSize,
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                SizedBox.expand(
                                                  child:
                                                      CircularProgressIndicator(
                                                        value: progress,
                                                        strokeWidth: isWarning
                                                            ? ringStroke
                                                            : 10,
                                                        backgroundColor:
                                                            spec.ringTrack,
                                                        valueColor:
                                                            AlwaysStoppedAnimation(
                                                              isWarning
                                                                  ? pulseColor
                                                                  : spec.accent,
                                                            ),
                                                      ),
                                                ),
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      _inGrace
                                                          ? (_isSahri
                                                              ? 'Sehri time finished'
                                                              : 'Iftar time started')
                                                          : 'Remaining Time',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: _inGrace
                                                                ? Colors.amber
                                                                    .shade700
                                                                : spec
                                                                    .secondaryText,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    AnimatedSwitcher(
                                                      duration: reduceMotion
                                                          ? Duration.zero
                                                          : const Duration(
                                                              milliseconds: 180,
                                                            ),
                                                      switchInCurve:
                                                          Curves.easeOutCubic,
                                                      switchOutCurve:
                                                          Curves.easeInCubic,
                                                      transitionBuilder:
                                                          (child, animation) {
                                                            return FadeTransition(
                                                              opacity: animation,
                                                              child: child,
                                                            );
                                                          },
                                                      child: Text(
                                                        _countdown,
                                                        key: ValueKey(
                                                          _countdown,
                                                        ),
                                                        style: countdownStyle,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 18),
                                      InfoChip(
                                        icon: Icons.schedule_rounded,
                                        label:
                                            '${_isSahri ? 'Ends at' : 'Begins at'} $timeText',
                                        accent: spec.accent,
                                        textColor: spec.primaryText,
                                        fill: spec.glassTint,
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        'Screen remains awake while focus mode is open.',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: spec.secondaryText,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// AccentIconBadge and InfoChip are now in shared_ui_widgets.dart
