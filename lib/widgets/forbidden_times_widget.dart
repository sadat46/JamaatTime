import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan_dart/adhan_dart.dart';
import '../services/prayer_calculation_service.dart';

class _ForbiddenVisualSpec {
  final List<Color> panelColors;
  final Color panelBorder;
  final Color panelShadow;
  final Color titleText;
  final Color countChipFill;
  final Color countChipText;
  final Color countChipIcon;
  final Color itemFill;
  final Color itemBorder;
  final Color itemPrimaryText;
  final Color itemSecondaryText;
  final Color itemTertiaryText;
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
    required this.countChipFill,
    required this.countChipText,
    required this.countChipIcon,
    required this.itemFill,
    required this.itemBorder,
    required this.itemPrimaryText,
    required this.itemSecondaryText,
    required this.itemTertiaryText,
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
    panelColors: [Color(0xFFFDF9F8), Color(0xFFF7F2EF)],
    panelBorder: Color(0x7AFFFFFF),
    panelShadow: Color(0x1A6C3B2B),
    titleText: Color(0xFF2C3036),
    countChipFill: Color(0xFFEFE5DF),
    countChipText: Color(0xFF735748),
    countChipIcon: Color(0xFF8E6650),
    itemFill: Color(0xCCFFFFFF),
    itemBorder: Color(0xFFD8CFC9),
    itemPrimaryText: Color(0xFF2C3036),
    itemSecondaryText: Color(0xFF5F6672),
    itemTertiaryText: Color(0xFF77808A),
    itemIconTint: Color(0xFFFAECE6),
    itemIconAccent: Color(0xFFA95C3A),
    activeFill: Color(0xFFFBEFE8),
    activeBorder: Color(0xFFC56D49),
    activeGlow: Color(0xFFA95C3A),
    activeTitle: Color(0xFF7C311B),
    activeChipFill: Color(0xFFF7DDD2),
    activeChipText: Color(0xFF8A3C23),
    activeChipBorder: Color(0xFFE6B39E),
    upcomingChipFill: Color(0xFFECEFF4),
    upcomingChipText: Color(0xFF5D6674),
    upcomingChipBorder: Color(0xFFD6DDE7),
  );

  static const _ForbiddenVisualSpec _dark = _ForbiddenVisualSpec(
    panelColors: [Color(0xFF2D2523), Color(0xFF231D1B)],
    panelBorder: Color(0x3FD5C4B8),
    panelShadow: Color(0x6B000000),
    titleText: Color(0xFFEFE7E3),
    countChipFill: Color(0x33433734),
    countChipText: Color(0xFFE3C8B7),
    countChipIcon: Color(0xFFD4A48D),
    itemFill: Color(0x402F2725),
    itemBorder: Color(0x66453C38),
    itemPrimaryText: Color(0xFFF2E9E5),
    itemSecondaryText: Color(0xFFD7C9C1),
    itemTertiaryText: Color(0xFFB8AAA2),
    itemIconTint: Color(0x3347302B),
    itemIconAccent: Color(0xFFEFB39A),
    activeFill: Color(0x554B2B24),
    activeBorder: Color(0xFFE29B78),
    activeGlow: Color(0xFFD48059),
    activeTitle: Color(0xFFFFD8C5),
    activeChipFill: Color(0x554D2D26),
    activeChipText: Color(0xFFF9CBB3),
    activeChipBorder: Color(0x77825F52),
    upcomingChipFill: Color(0x3A3F3A37),
    upcomingChipText: Color(0xFFC7BDB6),
    upcomingChipBorder: Color(0x66504743),
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

  const ForbiddenTimesWidget({super.key, required this.prayerTimes});

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
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Refresh every minute so isActive stays current
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.prayerTimes == null) {
      return const SizedBox.shrink();
    }

    final forbiddenWindows = PrayerCalculationService.instance
        .calculateForbiddenWindows(widget.prayerTimes!);

    if (forbiddenWindows.isEmpty) {
      return const SizedBox.shrink();
    }

    final spec = _ForbiddenVisualSpec.from(Theme.of(context).brightness);
    final now = DateTime.now();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: spec.panelGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: spec.panelBorder),
        boxShadow: [
          BoxShadow(
            color: spec.panelShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(spec, forbiddenWindows.length),
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

  Widget _buildSectionHeader(_ForbiddenVisualSpec spec, int windowCount) {
    final windowLabel = windowCount == 1 ? '1 window' : '$windowCount windows';
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: spec.itemIconTint,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
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
            'Forbidden Prayer Times',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: spec.titleText,
              height: 1.2,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: spec.countChipFill,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 11.5,
                color: spec.countChipIcon,
              ),
              const SizedBox(width: 4),
              Text(
                windowLabel,
                style: TextStyle(
                  fontSize: 10.5,
                  color: spec.countChipText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWindowCard({
    required ForbiddenWindow window,
    required bool isActive,
    required _ForbiddenVisualSpec spec,
    required bool reduceMotion,
  }) {
    if (isActive && !reduceMotion) {
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
    final animatedBorder = isActive
        ? Color.lerp(
            spec.activeBorder.withValues(alpha: 0.72),
            spec.activeBorder,
            pulseValue,
          )
        : spec.itemBorder;
    final borderColor = animatedBorder ?? spec.activeBorder;

    final shadowStrength = isActive && !reduceMotion
        ? (0.12 + (0.10 * pulseValue))
        : (isActive ? 0.14 : 0.06);

    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: isActive ? spec.activeFill : spec.itemFill,
        border: Border.all(color: borderColor, width: isActive ? 1.4 : 1.0),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? spec.activeGlow.withValues(alpha: shadowStrength)
                : Colors.black.withValues(alpha: shadowStrength),
            blurRadius: isActive ? 10 : 6,
            offset: const Offset(0, 3),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          window.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? spec.activeTitle
                                : spec.itemPrimaryText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildStatusChip(isActive: isActive, spec: spec),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          window.toRangeString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: spec.itemSecondaryText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$durationMinutes min',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: spec.itemTertiaryText,
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
    );
  }

  Widget _buildStatusChip({
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: chipBorder),
      ),
      child: Text(
        isActive ? 'Active' : 'Next',
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: chipText,
        ),
      ),
    );
  }
}
