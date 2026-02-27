import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan_dart/adhan_dart.dart';
import '../services/prayer_calculation_service.dart';
import 'shared_ui_widgets.dart';

/// Widget to display forbidden prayer time windows as styled cards
/// with a pulsing border on the active window.
class ForbiddenTimesWidget extends StatefulWidget {
  final PrayerTimes? prayerTimes;

  const ForbiddenTimesWidget({
    super.key,
    required this.prayerTimes,
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

    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: forbiddenWindows.map((window) {
        final isActive = window.isActive(now);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildWindowCard(window, isActive),
        );
      }).toList(),
    );
  }

  Widget _buildWindowCard(ForbiddenWindow window, bool isActive) {
    if (isActive) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return _buildCardContent(window, isActive, _pulseAnimation.value);
        },
      );
    }
    return _buildCardContent(window, isActive, 0.0);
  }

  Widget _buildCardContent(ForbiddenWindow window, bool isActive, double pulseValue) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isActive
            ? Colors.red.shade50
            : Colors.red.shade50.withValues(alpha: 0.5),
        border: Border.all(
          color: isActive
              ? Colors.red.withValues(alpha: pulseValue)
              : Colors.red.shade100,
          width: isActive ? 2.0 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.15 * pulseValue),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Warning icon
            Icon(
              Icons.warning_amber_rounded,
              size: 20,
              color: isActive ? Colors.red.shade700 : Colors.red.shade300,
            ),
            const SizedBox(width: 10),
            // Window name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    window.name,
                    style: TextStyle(
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive ? Colors.red.shade800 : Colors.red.shade700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    window.toRangeString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive ? Colors.red.shade600 : Colors.red.shade400,
                    ),
                  ),
                ],
              ),
            ),
            // Makruh badge
            InfoChip(
              icon: Icons.block,
              label: 'Makruh',
              accent: isActive ? Colors.red.shade700 : Colors.red.shade400,
              textColor: isActive ? Colors.red.shade800 : Colors.red.shade500,
              fill: isActive
                  ? Colors.red.shade100
                  : Colors.red.shade50,
              iconSize: 12,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ],
        ),
      ),
    );
  }
}
