import 'package:flutter/material.dart';

import 'workout_colors.dart';

/// „+ Dodaj serię” — przycisk w przerywanej ramce na całą szerokość karty.
class DashedAddButton extends StatelessWidget {
  const DashedAddButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: CustomPaint(
            painter: const _DashedRRectPainter(),
            child: SizedBox(
              height: 40,
              width: double.infinity,
              child: Center(
                child: Text(
                  '+ $label',
                  style: const TextStyle(
                    color: WorkoutColors.link,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter();

  static const _dash = 5.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 1.5;
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(stroke / 2),
      const Radius.circular(12),
    );
    final paint = Paint()
      ..color = WorkoutColors.dashedBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) => false;
}
