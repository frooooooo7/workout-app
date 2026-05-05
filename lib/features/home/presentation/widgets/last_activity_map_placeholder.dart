import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class LastActivityMapPlaceholder extends StatelessWidget {
  const LastActivityMapPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 130,
        height: 140,
        child: CustomPaint(
          painter: LastActivityRoutePainter(),
        ),
      ),
    );
  }
}

class LastActivityRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0D1117),
    );

    final streetPaint = Paint()
      ..color = const Color(0xFF1C2333)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final streets = [
      [Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.3)],
      [Offset(0, size.height * 0.65), Offset(size.width, size.height * 0.65)],
      [
        Offset(size.width * 0.25, 0),
        Offset(size.width * 0.25, size.height),
      ],
      [
        Offset(size.width * 0.7, 0),
        Offset(size.width * 0.7, size.height),
      ],
    ];
    for (final s in streets) {
      canvas.drawLine(s[0], s[1], streetPaint);
    }

    final routePath = Path()
      ..moveTo(size.width * 0.1, size.height * 0.82)
      ..cubicTo(
        size.width * 0.15,
        size.height * 0.55,
        size.width * 0.3,
        size.height * 0.65,
        size.width * 0.42,
        size.height * 0.45,
      )
      ..cubicTo(
        size.width * 0.5,
        size.height * 0.3,
        size.width * 0.6,
        size.height * 0.35,
        size.width * 0.72,
        size.height * 0.22,
      )
      ..cubicTo(
        size.width * 0.82,
        size.height * 0.12,
        size.width * 0.88,
        size.height * 0.18,
        size.width * 0.92,
        size.height * 0.15,
      );

    canvas.drawPath(
      routePath,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    final routeBounds = routePath.getBounds();
    canvas.drawPath(
      routePath,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFF4CAF7D),
            AppColors.primary,
          ],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ).createShader(routeBounds)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    _drawDot(
      canvas,
      Offset(size.width * 0.1, size.height * 0.82),
      const Color(0xFF4CAF7D),
    );
    _drawDot(
      canvas,
      Offset(size.width * 0.92, size.height * 0.15),
      AppColors.primary,
    );

    final markerCenter = Offset(size.width * 0.45, size.height * 0.43);
    canvas.drawCircle(
      markerCenter,
      13,
      Paint()..color = AppColors.primary.withValues(alpha: 0.85),
    );

    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final dbl = markerCenter;
    canvas.drawLine(
      Offset(dbl.dx - 6, dbl.dy),
      Offset(dbl.dx + 6, dbl.dy),
      iconPaint,
    );
    for (final dx in [-6.0, 6.0]) {
      canvas.drawLine(
        Offset(dbl.dx + dx, dbl.dy - 3.5),
        Offset(dbl.dx + dx, dbl.dy + 3.5),
        iconPaint..strokeWidth = 2.2,
      );
    }
  }

  void _drawDot(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(
      center,
      7,
      Paint()..color = color.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      center,
      4.5,
      Paint()..color = color,
    );
    canvas.drawCircle(
      center,
      4.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(LastActivityRoutePainter old) => false;
}
