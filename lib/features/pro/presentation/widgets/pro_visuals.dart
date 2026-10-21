import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'pro_motion.dart';

/// Linia trendu rysowana od lewej (`t` 0–1), opcjonalnie z wypełnieniem
/// i kropkami w punktach.
class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.color,
    required this.t,
    this.fill = false,
    this.dots = false,
  });

  /// Wartości 0–1 (1 = góra wykresu), równo rozłożone w poziomie.
  final List<double> points;
  final Color color;
  final double t;
  final bool fill;
  final bool dots;

  Offset _at(int i, Size size) => Offset(
    size.width * i / (points.length - 1),
    size.height - 4 - (size.height - 8) * points[i],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final line = Path()..moveTo(_at(0, size).dx, _at(0, size).dy);
    for (var i = 1; i < points.length; i++) {
      line.lineTo(_at(i, size).dx, _at(i, size).dy);
    }
    final PathMetric metric = line.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * t);

    if (fill && t > 0) {
      final area = Path.from(drawn);
      final end = metric.getTangentForOffset(metric.length * t)!.position;
      area
        ..lineTo(end.dx, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }

    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final dotPaint = Paint()..color = color;
    if (dots) {
      for (var i = 1; i < points.length; i++) {
        final reached = t >= i / (points.length - 1);
        if (reached) canvas.drawCircle(_at(i, size), 3, dotPaint);
      }
    } else if (t >= 1) {
      canvas.drawCircle(_at(points.length - 1, size), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.t != t || old.color != color;
}

/// Wykres postępu (teal, z wypełnieniem).
class ProProgressChart extends StatelessWidget {
  const ProProgressChart({super.key, this.delay = Duration.zero});

  final Duration delay;

  static const _points = [0.22, 0.38, 0.3, 0.62, 0.55, 0.85, 1.0];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 56,
        child: ProAnimated(
          delay: delay,
          duration: const Duration(milliseconds: 1100),
          builder: (context, t) => CustomPaint(
            size: Size.infinite,
            painter: _TrendPainter(
              points: _points,
              color: AppColors.statTeal,
              t: t,
              fill: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// Trend pomiarów (fiolet, z kropkami).
class ProMeasurementsChart extends StatelessWidget {
  const ProMeasurementsChart({
    super.key,
    this.delay = Duration.zero,
    this.height = 56,
  });

  final Duration delay;
  final double height;

  static const _points = [0.3, 0.42, 0.55, 0.7, 0.85];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: ProAnimated(
          delay: delay,
          duration: const Duration(milliseconds: 1100),
          builder: (context, t) => CustomPaint(
            size: Size.infinite,
            painter: _TrendPainter(
              points: _points,
              color: AppColors.planLegs,
              t: t,
              dots: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// Słupki z ostatnim złotym „PR”.
class ProRecordsBars extends StatelessWidget {
  const ProRecordsBars({super.key, this.delay = Duration.zero});

  final Duration delay;

  static const _heights = [22.0, 30.0, 26.0, 38.0, 56.0];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 56,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < _heights.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: ProAnimated(
                  delay: delay + Duration(milliseconds: 100 * i),
                  builder: (context, t) {
                    final last = i == _heights.length - 1;
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: _heights[i] * t,
                        decoration: BoxDecoration(
                          color: last
                              ? AppColors.record
                              : AppColors.borderStrong,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        alignment: Alignment.topCenter,
                        padding: const EdgeInsets.only(top: 3),
                        child: last && t > 0.9
                            ? Text(
                                'PR',
                                style: AppTextStyles.number(
                                  size: 13,
                                  weight: FontWeight.w800,
                                  color: AppColors.background,
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Trzy plany w kolorach Push / Pull / Legs, wsuwane z lewej.
class ProPlanBars extends StatelessWidget {
  const ProPlanBars({super.key, this.delay = Duration.zero});

  final Duration delay;

  static const _colors = [
    AppColors.planPush,
    AppColors.planPull,
    AppColors.planLegs,
  ];
  static const _widths = [0.92, 0.78, 0.64];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _colors.length; i++) ...[
              if (i > 0) const SizedBox(height: 5),
              ProAnimated(
                delay: delay + Duration(milliseconds: 120 * i),
                duration: const Duration(milliseconds: 700),
                builder: (context, t) => FractionallySizedBox(
                  widthFactor: _widths[i] * t,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: _colors[i].withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(7),
                      border: Border(
                        left: BorderSide(color: _colors[i], width: 4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
