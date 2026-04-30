import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan_dart/adhan_dart.dart';
import '../core/app_theme_tokens.dart';
import '../core/locale_text.dart';
import '../services/prayer_time_engine.dart';
import '../utils/locale_digits.dart';

class _ForbiddenVisualSpec {
  final List<Color> panelColors;
  final Color panelBorder;
  final Color panelShadow;
  final Color titleText;
  final Color noteFill;
  final Color noteBorder;
  final Color noteText;
  final Color noteIcon;
  final Color itemFill;
  final Color itemBorder;
  final Color itemPrimaryText;
  final Color itemSecondaryText;
  final Color itemIconTint;
  final Color itemIconAccent;
  final Color activeFill;
  final Color activeBorder;
  final Color activeGlow;
  final Color activeTitle;
  final Color activeChipFill;
  final Color activeChipText;
  final Color activeChipBorder;
  final Color upcomingChipFill;
  final Color upcomingChipText;
  final Color upcomingChipBorder;

  const _ForbiddenVisualSpec({
    required this.panelColors,
    required this.panelBorder,
    required this.panelShadow,
    required this.titleText,
    required this.noteFill,
    required this.noteBorder,
    required this.noteText,
    required this.noteIcon,
    required this.itemFill,
    required this.itemBorder,
    required this.itemPrimaryText,
    required this.itemSecondaryText,
    required this.itemIconTint,
    required this.itemIconAccent,
    required this.activeFill,
    required this.activeBorder,
    required this.activeGlow,
    required this.activeTitle,
    required this.activeChipFill,
    required this.activeChipText,
    required this.activeChipBorder,
    required this.upcomingChipFill,
    required this.upcomingChipText,
    required this.upcomingChipBorder,
  });

  static const _ForbiddenVisualSpec _light = _ForbiddenVisualSpec(
    panelColors: [Color(0xFFFFFCF8), Color(0xFFFFF5EF)],
    panelBorder: Color(0xFFEEDFD4),
    panelShadow: Color(0x10684632),
    titleText: AppColors.textPrimary,
    noteFill: Color(0xFFFFF8F2),
    noteBorder: Color(0xFFEADBCD),
    noteText: Color(0xFF7C6658),
    noteIcon: Color(0xFFB36C3B),
    itemFill: Color(0xFFFFFEFC),
    itemBorder: Color(0xFFECE1D8),
    itemPrimaryText: AppColors.textPrimary,
    itemSecondaryText: Color(0xFF69756F),
    itemIconTint: Color(0xFFFFF0E6),
    itemIconAccent: Color(0xFFB36C3B),
    activeFill: Color(0xFFFFF4ED),
    activeBorder: Color(0xFFC98258),
    activeGlow: Color(0xFFB36C3B),
    activeTitle: Color(0xFF6F321D),
    activeChipFill: Color(0xFFFFE8DA),
    activeChipText: Color(0xFF7A3E25),
    activeChipBorder: Color(0xFFE8BEA7),
    upcomingChipFill: Color(0xFFFAF6F2),
    upcomingChipText: Color(0xFF66584E),
    upcomingChipBorder: Color(0xFFE6DDD5),
  );

  static const _ForbiddenVisualSpec _dark = _ForbiddenVisualSpec(
    panelColors: [Color(0xFF2A2421), Color(0xFF211C1A)],
    panelBorder: Color(0x4AD6C4B8),
    panelShadow: Color(0x59000000),
    titleText: Color(0xFFF4ECE7),
    noteFill: Color(0x38413734),
    noteBorder: Color(0x58594D47),
    noteText: Color(0xFFD4C6BE),
    noteIcon: Color(0xFFE6A583),
    itemFill: Color(0x4A302825),
    itemBorder: Color(0x5C5C4C43),
    itemPrimaryText: Color(0xFFF4ECE8),
    itemSecondaryText: Color(0xFFD1C4BC),
    itemIconTint: Color(0x3D54342B),
    itemIconAccent: Color(0xFFF0B394),
    activeFill: Color(0x62472B24),
    activeBorder: Color(0xFFE0A07F),
    activeGlow: Color(0xFFD08A62),
    activeTitle: Color(0xFFFFD9C7),
    activeChipFill: Color(0x604C2C25),
    activeChipText: Color(0xFFFFD0B8),
    activeChipBorder: Color(0x80825F52),
    upcomingChipFill: Color(0x42413B37),
    upcomingChipText: Color(0xFFD0C5BE),
    upcomingChipBorder: Color(0x70554A45),
  );

  static _ForbiddenVisualSpec from(Brightness brightness) {
    return brightness == Brightness.dark ? _dark : _light;
  }

  LinearGradient get panelGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: panelColors,
  );
}

/// Widget to display forbidden prayer time windows as styled cards
/// with a pulsing border on the active window.
class ForbiddenTimesWidget extends StatefulWidget {
  final PrayerTimes? prayerTimes;
  final bool isActive;

  const ForbiddenTimesWidget({
    super.key,
    required this.prayerTimes,
    this.isActive = true,
  });

  @override
  State<ForbiddenTimesWidget> createState() => _ForbiddenTimesWidgetState();
}

class _ForbiddenTimesWidgetState extends State<ForbiddenTimesWidget>
    with SingleTickerProviderStateMixin {
  Timer? _refreshTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Pulse animation for active window border
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _syncRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant ForbiddenTimesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive ||
        oldWidget.prayerTimes != widget.prayerTimes) {
      _syncRefreshTimer();
      if (!widget.isActive) {
        _setPulseActive(false);
      }
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _syncRefreshTimer() {
    if (!widget.isActive) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      return;
    }
    if (_refreshTimer?.isActive ?? false) {
      return;
    }
    // Refresh every minute so active windows stay current.
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && widget.isActive) setState(() {});
    });
  }

  void _setPulseActive(bool enabled) {
    if (enabled) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
      return;
    }
    if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
    _pulseController.reset();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _localizeDigits(BuildContext context, String value) {
    return LocaleDigits.localize(value, Localizations.localeOf(context));
  }

  String _localizedWindowName(BuildContext context, String canonicalName) {
    switch (canonicalName) {
      case 'After Sunrise':
        return context.tr(bn: 'সূর্যোদয়ের পরে', en: 'After Sunrise');
      case 'Zawal (Zenith)':
        return context.tr(bn: 'জাওয়াল (মধ্যাহ্ন)', en: 'Zawal (Zenith)');
      case 'Before Sunset':
        return context.tr(bn: 'সূর্যাস্তের আগে', en: 'Before Sunset');
      default:
        return canonicalName;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.prayerTimes == null) {
      return const SizedBox.shrink();
    }

    final forbiddenWindows = PrayerTimeEngine.instance
        .calculateForbiddenWindows(widget.prayerTimes!);

    if (forbiddenWindows.isEmpty) {
      return const SizedBox.shrink();
    }

    final spec = _ForbiddenVisualSpec.from(Theme.of(context).brightness);
    final now = DateTime.now();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final hasActiveWindow = forbiddenWindows.any((window) {
      return window.isActive(now);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setPulseActive(widget.isActive && hasActiveWindow && !reduceMotion);
      }
    });

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: spec.panelGradient,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: spec.panelBorder),
        boxShadow: [
          BoxShadow(
            color: spec.panelShadow,
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, spec),
            const SizedBox(height: 6),
            _buildAreaNote(context, spec),
            const SizedBox(height: 8),
            for (int i = 0; i < forbiddenWindows.length; i++) ...[
              _buildWindowCard(
                window: forbiddenWindows[i],
                isActive: forbiddenWindows[i].isActive(now),
                spec: spec,
                reduceMotion: reduceMotion,
              ),
              if (i != forbiddenWindows.length - 1) const SizedBox(height: 7),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, _ForbiddenVisualSpec spec) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: spec.itemIconTint,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.48)),
            boxShadow: [
              BoxShadow(
                color: spec.itemIconAccent.withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            Icons.warning_amber_rounded,
            size: 17,
            color: spec.itemIconAccent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr(
              bn: 'নিষিদ্ধ নামাজের সময়',
              en: 'Forbidden Prayer Times',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: spec.titleText,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAreaNote(BuildContext context, _ForbiddenVisualSpec spec) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: spec.noteFill,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: spec.noteBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded, size: 12, color: spec.noteIcon),
          const SizedBox(width: 4),
          Text(
            context.tr(bn: 'হারাম এলাকা ব্যতীত', en: 'Except Haram area'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: spec.noteText,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowCard({
    required ForbiddenWindow window,
    required bool isActive,
    required _ForbiddenVisualSpec spec,
    required bool reduceMotion,
  }) {
    if (widget.isActive && isActive && !reduceMotion) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return _buildCardContent(
            window: window,
            isActive: isActive,
            pulseValue: _pulseAnimation.value,
            spec: spec,
            reduceMotion: reduceMotion,
          );
        },
      );
    }
    return _buildCardContent(
      window: window,
      isActive: isActive,
      pulseValue: 1.0,
      spec: spec,
      reduceMotion: reduceMotion,
    );
  }

  Widget _buildCardContent({
    required ForbiddenWindow window,
    required bool isActive,
    required double pulseValue,
    required _ForbiddenVisualSpec spec,
    required bool reduceMotion,
  }) {
    final durationMinutes = window.end.difference(window.start).inMinutes.abs();
    final localizedDurationMinutes = _localizeDigits(
      context,
      '$durationMinutes',
    );
    final localizedRange = _localizeDigits(context, window.toRangeString());
    final durationLabel = context.isEnglish
        ? '$localizedDurationMinutes min'
        : '$localizedDurationMinutes মিনিট';
    final animatedBorder = isActive
        ? Color.lerp(
            spec.activeBorder.withValues(alpha: 0.72),
            spec.activeBorder,
            pulseValue,
          )
        : spec.itemBorder;
    final borderColor = animatedBorder ?? spec.activeBorder;

    final shadowStrength = isActive && !reduceMotion
        ? (0.08 + (0.06 * pulseValue))
        : (isActive ? 0.10 : 0.035);

    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.row),
        color: isActive ? spec.activeFill : spec.itemFill,
        border: Border.all(color: borderColor, width: isActive ? 1.25 : 1.0),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? spec.activeGlow.withValues(alpha: shadowStrength)
                : Colors.black.withValues(alpha: shadowStrength),
            blurRadius: isActive ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: spec.itemIconTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.block_rounded,
                size: 14,
                color: isActive ? spec.activeBorder : spec.itemIconAccent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: Text(
                _localizedWindowName(context, window.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isActive ? spec.activeTitle : spec.itemPrimaryText,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 4,
              child: Text(
                localizedRange,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: spec.itemSecondaryText,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _buildDurationChip(
              label: durationLabel,
              isActive: isActive,
              spec: spec,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationChip({
    required String label,
    required bool isActive,
    required _ForbiddenVisualSpec spec,
  }) {
    final chipFill = isActive ? spec.activeChipFill : spec.upcomingChipFill;
    final chipText = isActive ? spec.activeChipText : spec.upcomingChipText;
    final chipBorder = isActive
        ? spec.activeChipBorder
        : spec.upcomingChipBorder;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: chipFill,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: chipBorder),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: chipText,
        ),
      ),
    );
  }
}
