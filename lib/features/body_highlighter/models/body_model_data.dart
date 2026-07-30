import 'dart:ui';
import 'muscle_region.dart';

/// Class containing parsed SVG data for a body model (viewBox, outline, regions).
class BodyModelData {
  final Rect viewBox;
  final Path? outline;
  final List<MuscleRegion> regions;

  const BodyModelData({
    required this.viewBox,
    this.outline,
    required this.regions,
  });
}
