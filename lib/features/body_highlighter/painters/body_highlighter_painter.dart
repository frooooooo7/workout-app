import 'dart:math';
import 'package:flutter/material.dart';

import '../models/body_model_data.dart';
import '../models/body_side.dart';
import '../models/body_highlighter_style.dart';
import '../models/muscle_highlight.dart';
import '../models/muscle_intensity.dart';

/// Painter responsible for rendering anatomical body mannequin paths and active highlights.
class BodyHighlighterPainter extends CustomPainter {
  final BodyModelData data;
  final Map<String, Color> animatedMuscleColors;
  final Set<MuscleHighlight> highlights;
  final BodyHighlighterStyle style;

  BodyHighlighterPainter({
    required this.data,
    required this.animatedMuscleColors,
    required this.highlights,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final vb = data.viewBox;

    // Calculate aspect-fit scale and centering offsets
    final scale = min(size.width / vb.width, size.height / vb.height);
    final dx = (size.width - vb.width * scale) / 2 - vb.left * scale;
    final dy = (size.height - vb.height * scale) / 2 - vb.top * scale;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    // Paints setup
    final fillPaint = Paint()..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.strokeWidth / scale
      ..color = style.inactiveStroke;

    final activeStrokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (style.strokeWidth * 1.5) / scale
      ..color = style.activeStroke;

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0 / scale
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    // 1. Draw inactive and active muscle regions
    for (final region in data.regions) {
      final colorKey = '${region.slug}_${region.side.name}';
      final fillColor = animatedMuscleColors[colorKey] ?? style.inactiveFill;
      fillPaint.color = fillColor;

      final highlight = _findHighlightForRegion(region.slug, region.side);
      final isActive =
          highlight != null && highlight.intensity != MuscleIntensity.inactive;

      // Glow effect for high intensity active muscles
      if (isActive &&
          style.glowEnabled &&
          highlight.intensity == MuscleIntensity.high) {
        glowPaint.color = fillColor.withValues(alpha: 0.6);
        for (final path in region.paths) {
          canvas.drawPath(path, glowPaint);
        }
      }

      // Fill muscle paths
      for (final path in region.paths) {
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, isActive ? activeStrokePaint : strokePaint);
      }
    }

    // 2. Draw external body outline
    if (data.outline != null) {
      final outlinePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (style.strokeWidth * 2.0) / scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = style.outlineColor;

      canvas.drawPath(data.outline!, outlinePaint);
    }

    canvas.restore();
  }

  MuscleHighlight? _findHighlightForRegion(String slug, BodySide regionSide) {
    for (final h in highlights) {
      if (h.muscle == slug) {
        if (h.side == BodySide.common ||
            regionSide == BodySide.common ||
            h.side == regionSide) {
          return h;
        }
      }
    }
    return null;
  }

  @override
  bool shouldRepaint(covariant BodyHighlighterPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.animatedMuscleColors != animatedMuscleColors ||
        oldDelegate.highlights != highlights ||
        oldDelegate.style != style;
  }
}
