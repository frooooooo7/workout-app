import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Linia progresu z wypełnieniem gradientem. Rysuje się od lewej przy
/// pierwszym pokazaniu; ostatni punkt ma poświatę.
class ExerciseProgressChart extends StatefulWidget {
  const ExerciseProgressChart({
    super.key,
    required this.values,
    this.height = 96,
    this.color = AppColors.primaryVariant,
  });

  /// Wartości od najstarszej do najnowszej (co najmniej 2).
  final List<double> values;
  final double height;
  final Color color;

  @override
  State<ExerciseProgressChart> createState() => _ExerciseProgressChartState();
}

class _ExerciseProgressChartState extends State<ExerciseProgressChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) => CustomPaint(
          painter: _ProgressPainter(
            values: widget.values,
            color: widget.color,
            progress: _progress.value,
          ),
        ),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({
    required this.values,
    required this.color,
    required this.progress,
  });

  final List<double> values;
  final Color color;
  final double progress;

  static const _verticalPadding = 10.0;
  static const _horizontalPadding = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    // Płaska seria (ten sam wynik) rysuje się pośrodku, a nie przy krawędzi.
    final span = maxValue - minValue == 0 ? 1.0 : maxValue - minValue;
    final chartHeight = size.height - _verticalPadding * 2;
    final chartWidth = size.width - _horizontalPadding * 2;

    Offset pointAt(int index) {
      final x = _horizontalPadding + chartWidth * index / (values.length - 1);
      final normalized = maxValue - minValue == 0
          ? 0.5
          : (values[index] - minValue) / span;
      final y = _verticalPadding + chartHeight * (1 - normalized);
      return Offset(x, y);
    }

    final points = [for (var i = 0; i < values.length; i++) pointAt(i)];

    // Siatka pomocnicza: trzy przerywane linie poziome.
    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var i = 0; i < 3; i++) {
      final y = _verticalPadding + chartHeight * i / 2;
      for (var x = 0.0; x < size.width; x += 6) {
        canvas.drawLine(Offset(x, y), Offset(x + 3, y), gridPaint);
      }
    }

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final midX = (previous.dx + current.dx) / 2;
      line.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

    final area = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    if (progress < 1) return;
    final last = points.last;
    canvas.drawCircle(last, 9, Paint()..color = color.withValues(alpha: 0.18));
    canvas.drawCircle(last, 4.5, Paint()..color = color);
    canvas.drawCircle(
      last,
      4.5,
      Paint()
        ..color = AppColors.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_ProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.values != values;
}
