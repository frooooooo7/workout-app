import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';

/// Mały wykres liniowy bez osi: linia, delikatne wypełnienie i kropka na
/// ostatnim punkcie. [flat] przygasza go na szaro („bez zmian”).
class StatsSparkline extends StatelessWidget {
  const StatsSparkline({
    super.key,
    required this.values,
    this.flat = false,
    this.width = 96,
    this.height = 34,
  });

  final List<double> values;
  final bool flat;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: values.length < 2
          ? const SizedBox.shrink()
          : CustomPaint(
              painter: _SparklinePainter(
                values: values,
                color: flat ? AppColors.textMuted : AppColors.primaryVariant,
              ),
            ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 4.0;
    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);
    if (hi - lo < 1e-9) {
      lo -= 1;
      hi += 1;
    }
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    Offset at(int i) => Offset(
      pad + w * i / (values.length - 1),
      pad + h * (1 - (values[i] - lo) / (hi - lo)),
    );

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p = at(i);
      line.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(line)
      ..lineTo(at(values.length - 1).dx, size.height)
      ..lineTo(at(0).dx, size.height)
      ..close();

    canvas.drawPath(
      fill,
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
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(at(values.length - 1), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color || old.values != values;
}
