import 'dart:ui';
import 'body_side.dart';
import 'body_view.dart';

/// Represents a distinct muscle region in the anatomical mannequin.
/// Stores pre-parsed [Path] objects for performance efficiency.
class MuscleRegion {
  final String id;
  final String slug;
  final BodySide side;
  final BodyView view;
  final List<Path> paths;

  const MuscleRegion({
    required this.id,
    required this.slug,
    required this.side,
    required this.view,
    required this.paths,
  });

  /// Checks if any sub-path of this region contains the given point.
  bool contains(Offset point) {
    for (final path in paths) {
      if (path.contains(point)) {
        return true;
      }
    }
    return false;
  }
}
