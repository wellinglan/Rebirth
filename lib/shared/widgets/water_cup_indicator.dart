import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

class WaterCupIndicator extends StatelessWidget {
  const WaterCupIndicator({
    required this.waterIntakeMl,
    super.key,
    this.visualCapacityMl = 2000,
    this.animate = true,
  }) : assert(visualCapacityMl > 0);

  final int? waterIntakeMl;
  final int visualCapacityMl;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final value = waterIntakeMl;
    final ratio = waterLevelFraction(value, visualCapacityMl);
    final label = value == null ? '当前饮水量未记录' : '当前饮水量 $value 毫升';
    final duration = animate
        ? AppMotion.responsive(context, AppMotion.emphasized)
        : Duration.zero;
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              key: const ValueKey('waterCupCanvas'),
              width: 156,
              height: 190,
              child: TweenAnimationBuilder<double>(
                key: ValueKey('waterLevel$value'),
                tween: Tween<double>(end: ratio),
                duration: duration,
                curve: Curves.easeOutCubic,
                builder: (context, level, _) => CustomPaint(
                  painter: _WaterCupPainter(
                    level: level,
                    outline: Theme.of(context).colorScheme.outline,
                    water: const Color(0xFF48A9C5),
                    surface: Theme.of(context).colorScheme.surface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value == null ? '未记录' : '$value ml',
              key: const ValueKey('waterCupExactValue'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '水杯仅用于显示相对水位',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

double waterLevelFraction(int? waterIntakeMl, int visualCapacityMl) {
  if (waterIntakeMl == null) return 0;
  return (waterIntakeMl / visualCapacityMl).clamp(0.0, 1.0);
}

class _WaterCupPainter extends CustomPainter {
  const _WaterCupPainter({
    required this.level,
    required this.outline,
    required this.water,
    required this.surface,
  });

  final double level;
  final Color outline;
  final Color water;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final glass = RRect.fromRectAndRadius(
      Rect.fromLTRB(20, 10, size.width - 20, size.height - 12),
      const Radius.circular(18),
    );
    canvas.drawRRect(glass, Paint()..color = surface.withValues(alpha: 0.6));
    canvas.save();
    canvas.clipRRect(glass.deflate(5));
    final inner = glass.deflate(5).outerRect;
    final waterTop = inner.bottom - inner.height * level;
    canvas.drawRect(
      Rect.fromLTRB(inner.left, waterTop, inner.right, inner.bottom),
      Paint()..color = water.withValues(alpha: 0.82),
    );
    if (level > 0) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(inner.center.dx, waterTop),
          width: inner.width,
          height: 10,
        ),
        Paint()..color = water,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      glass,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _WaterCupPainter oldDelegate) {
    return level != oldDelegate.level ||
        outline != oldDelegate.outline ||
        water != oldDelegate.water ||
        surface != oldDelegate.surface;
  }
}
