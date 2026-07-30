import 'package:flutter/material.dart';
import 'body_side.dart';
import 'muscle_intensity.dart';

/// Defines highlighting for a specific muscle group or side.
class MuscleHighlight {
  final String muscle;
  final MuscleIntensity intensity;
  final BodySide side;
  final Color? customColor;

  const MuscleHighlight({
    required this.muscle,
    required this.intensity,
    this.side = BodySide.common,
    this.customColor,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MuscleHighlight &&
          runtimeType == other.runtimeType &&
          muscle == other.muscle &&
          intensity == other.intensity &&
          side == other.side &&
          customColor == other.customColor;

  @override
  int get hashCode =>
      muscle.hashCode ^
      intensity.hashCode ^
      side.hashCode ^
      customColor.hashCode;
}
