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
    panelColors: [AppColors.warningSoft, Color(0xFFFFFBF8)],
    panelBorder: AppColors.warningBorder,
    panelShadow: Color(0x126C3B2B),
    titleText: AppColors.textPrimary,
    itemFill: AppColors.cardBackground,
    itemBorder: Color(0xFFE7D9CF),
    itemPrimaryText: AppColors.textPrimary,
    itemSecondaryText: AppColors.textSecondary,
    itemIconTint: Color(0xFFFCEDE5),
    itemIconAccent: AppColors.warningAccent,
    activeFill: Color(0xFFFFF2EA),
    activeBorder: Color(0xFFD18762),
    activeGlow: AppColors.warningAccent,
    activeTitle: Color(0xFF813D24),
    activeChipFill: Color(0xFFF9E0D2),
    activeChipText: Color(0xFF8A3C23),
    activeChipBorder: Color(0xFFE7B9A3),
    upcomingChipFill: Color(0xFFF3F5F4),
    upcomingChipText: AppColors.textSecondary,
    upcomingChipBorder: AppColors.borderLight,
  );

  static const _ForbiddenVisualSpec _dark = _ForbiddenVisualSpec(
    panelColors: [Color(0xFF2D2523), Color(0xFF231D1B)],
    panelBorder: Color(0x3FD5C4B8),
    panelShadow: Color(0x6B000000),
    titleText: Color(0xFFEFE7E3),
    itemFill: Color(0x402F2725),
    itemBorder: Color(0x66453C38),
    itemPrimaryText: Color(0xFFF2E9E5),
    itemSecondaryText: Color(0xFFD7C9C1),
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

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: spec.panelGradient,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: spec.panelBorder),
        boxShadow: [
          BoxShadow(
            color: spec.panelShadow,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, spec),
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
            blurRadius: isActive ? 9 : 5,
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
        borderRadius: BorderRadius.circular(10),
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
