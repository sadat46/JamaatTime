import 'package:flutter/material.dart';
import '../core/constants.dart';

/// Circular badge with icon, glow box-shadow, semi-transparent tint background.
///
/// Extracted from `_AccentIconBadge` in `sahri_iftar_widget.dart` for cross-file reuse.
class AccentIconBadge extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final Color tint;
  final double size;
  final double iconSize;

  const AccentIconBadge({
    super.key,
    required this.icon,
    required this.accent,
    required this.tint,
    this.size = 52,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tint.withValues(alpha: 0.85),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 14,
            spreadRadius: 0.8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: accent, size: iconSize),
    );
  }
}

/// Rounded pill with icon + label, glass-effect border.
///
/// Extracted from `_InfoChip` in `sahri_iftar_widget.dart` for cross-file reuse.
class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final Color textColor;
  final Color fill;
  final EdgeInsetsGeometry padding;
  final double iconSize;
  final TextStyle? textStyle;

  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.textColor,
    required this.fill,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    this.iconSize = 14,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: fill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: accent),
            const SizedBox(width: 6),
            Text(
              label,
              style:
                  textStyle ??
                  Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header with a 4 px rounded green left accent strip + bold title.
class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: AppConstants.brandGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppConstants.brandGreenDark,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
