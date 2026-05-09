import 'package:flutter/material.dart';

import '../../../core/app_theme_tokens.dart';
import '../home_controller.dart';

class PrayerGlowBand extends StatelessWidget {
  const PrayerGlowBand({super.key, required this.controller});

  final HomeController controller;

  static const double _bandHeight = 24;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _bandHeight,
      width: double.infinity,
      child: CustomPaint(
        painter: _AmbientGlowPainter(
          controller: controller,
          color: AppColors.activeAccent,
        ),
      ),
    );
  }
}

class _AmbientGlowPainter extends CustomPainter {
  _AmbientGlowPainter({required this.controller, required this.color})
    : super(repaint: controller.nowNotifier);

  final HomeController controller;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final times = controller.orderedPrayerDateTimes;
    if (times.length < 2 || times.any((t) => t == null)) return;

    final now = DateTime.now();
    final n = times.length;
    double cellCenter(int k) => (k + 0.5) * (size.width / n);

    int i = -1;
    for (var k = 0; k < n; k++) {
      if (!times[k]!.isAfter(now)) i = k;
    }

    double x;
    double alphaMul = 1.0;
    if (i < 0) {
      x = cellCenter(0);
      alphaMul = 0.4;
    } else if (i >= n - 1) {
      x = cellCenter(n - 1);
      alphaMul = 0.4;
    } else {
      final spanMs = times[i + 1]!.difference(times[i]!).inMilliseconds;
      final progress = spanMs <= 0
          ? 0.0
          : (now.difference(times[i]!).inMilliseconds / spanMs).clamp(
              0.0,
              1.0,
            );
      x = cellCenter(i) + progress * (cellCenter(i + 1) - cellCenter(i));
    }

    final cy = size.height / 2;
    final glowRect = Rect.fromCenter(
      center: Offset(x, cy),
      width: 70,
      height: 30,
    );
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.45 * alphaMul),
          color.withValues(alpha: 0.18 * alphaMul),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.30, 0.65],
      ).createShader(glowRect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(glowRect, glowPaint);

    final streakRect = Rect.fromCenter(
      center: Offset(x, cy),
      width: 70,
      height: 1,
    );
    final streakPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.9 * alphaMul),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(streakRect);
    canvas.drawRect(streakRect, streakPaint);
  }

  @override
  bool shouldRepaint(covariant _AmbientGlowPainter old) =>
      old.controller != controller || old.color != color;
}
