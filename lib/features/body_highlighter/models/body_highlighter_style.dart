import 'package:flutter/material.dart';
import 'muscle_intensity.dart';

/// Style configuration for the anatomical mannequin painter.
class BodyHighlighterStyle {
  final Color inactiveFill;
  final Color inactiveStroke;
  final Color outlineColor;
  final Color lowColor;
  final Color mediumColor;
  final Color highColor;
  final Color activeStroke;
  final bool glowEnabled;
  final double strokeWidth;

  const BodyHighlighterStyle({
    required this.inactiveFill,
    required this.inactiveStroke,
    required this.outlineColor,
    required this.lowColor,
    required this.mediumColor,
    required this.highColor,
    required this.activeStroke,
    this.glowEnabled = true,
    this.strokeWidth = 1.0,
  });

  /// Dark mode preset matching modern UI design.
  const factory BodyHighlighterStyle.dark({
    Color inactiveFill,
    Color inactiveStroke,
    Color outlineColor,
    Color lowColor,
    Color mediumColor,
    Color highColor,
    Color activeStroke,
    bool glowEnabled,
    double strokeWidth,
  }) = _DarkStyle;

  /// Light mode preset.
  const factory BodyHighlighterStyle.light({
    Color inactiveFill,
    Color inactiveStroke,
    Color outlineColor,
    Color lowColor,
    Color mediumColor,
    Color highColor,
    Color activeStroke,
    bool glowEnabled,
    double strokeWidth,
  }) = _LightStyle;

  /// Helper to get target color based on [MuscleIntensity].
  Color getColorForIntensity(MuscleIntensity intensity) {
    switch (intensity) {
      case MuscleIntensity.inactive:
        return inactiveFill;
      case MuscleIntensity.low:
        return lowColor;
      case MuscleIntensity.medium:
        return mediumColor;
      case MuscleIntensity.high:
        return highColor;
    }
  }
}

class _DarkStyle extends BodyHighlighterStyle {
  const _DarkStyle({
    super.inactiveFill = const Color(0xFF1E293B),
    super.inactiveStroke = const Color(0xFF0F172A),
    super.outlineColor = const Color(0xFF475569),
    super.lowColor = const Color(0xFF38BDF8),
    super.mediumColor = const Color(0xFF2563EB),
    super.highColor = const Color(0xFF0284C7),
    super.activeStroke = const Color(0xFF60A5FA),
    super.glowEnabled = true,
    super.strokeWidth = 1.0,
  });
}

class _LightStyle extends BodyHighlighterStyle {
  const _LightStyle({
    super.inactiveFill = const Color(0xFFE2E8F0),
    super.inactiveStroke = const Color(0xFFCBD5E1),
    super.outlineColor = const Color(0xFF94A3B8),
    super.lowColor = const Color(0xFF93C5FD),
    super.mediumColor = const Color(0xFF3B82F6),
    super.highColor = const Color(0xFF1D4ED8),
    super.activeStroke = const Color(0xFF1E40AF),
    super.glowEnabled = false,
    super.strokeWidth = 1.0,
  });
}
