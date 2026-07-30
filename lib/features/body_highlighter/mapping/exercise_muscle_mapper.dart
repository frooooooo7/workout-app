import '../models/body_side.dart';
import '../models/muscle_highlight.dart';
import '../models/muscle_intensity.dart';

/// Represents muscle involvement mapping for a specific exercise or workout session.
class ExerciseMuscleMapping {
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> tertiaryMuscles;
  final BodySide side;

  const ExerciseMuscleMapping({
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.tertiaryMuscles = const [],
    this.side = BodySide.common,
  });
}

/// Helper service to convert workout session exercise mappings into mannequin highlights.
class ExerciseMuscleMapper {
  /// Maps exercise muscle lists into a set of [MuscleHighlight] entries.
  /// Aggregates intensity levels when a muscle is targeted across multiple exercises:
  /// - Priority rule: Primary -> High, Secondary -> Medium, Tertiary -> Low.
  /// - Cumulative escalation rule: Multiple secondary hits (>= 2) elevate to High.
  ///   Multiple tertiary hits (>= 2) elevate to Medium.
  static Set<MuscleHighlight> mapExercisesToHighlights(
    List<ExerciseMuscleMapping> mappings,
  ) {
    // Key: '${muscle}_${side.name}' -> List of intensity scores
    final Map<String, _MuscleScore> scores = {};

    for (final mapping in mappings) {
      for (final muscle in mapping.primaryMuscles) {
        _addScore(scores, muscle, mapping.side, MuscleIntensity.high);
      }
      for (final muscle in mapping.secondaryMuscles) {
        _addScore(scores, muscle, mapping.side, MuscleIntensity.medium);
      }
      for (final muscle in mapping.tertiaryMuscles) {
        _addScore(scores, muscle, mapping.side, MuscleIntensity.low);
      }
    }

    final highlights = <MuscleHighlight>{};

    scores.forEach((_, scoreData) {
      final intensity = scoreData.calculateFinalIntensity();
      highlights.add(
        MuscleHighlight(
          muscle: scoreData.muscle,
          side: scoreData.side,
          intensity: intensity,
        ),
      );
    });

    return highlights;
  }

  static void _addScore(
    Map<String, _MuscleScore> map,
    String muscle,
    BodySide side,
    MuscleIntensity intensity,
  ) {
    final key = '${muscle}_${side.name}';
    final entry = map.putIfAbsent(
      key,
      () => _MuscleScore(muscle: muscle, side: side),
    );
    entry.addIntensity(intensity);
  }
}

class _MuscleScore {
  final String muscle;
  final BodySide side;

  int highCount = 0;
  int mediumCount = 0;
  int lowCount = 0;

  _MuscleScore({required this.muscle, required this.side});

  void addIntensity(MuscleIntensity intensity) {
    switch (intensity) {
      case MuscleIntensity.high:
        highCount++;
        break;
      case MuscleIntensity.medium:
        mediumCount++;
        break;
      case MuscleIntensity.low:
        lowCount++;
        break;
      case MuscleIntensity.inactive:
        break;
    }
  }

  MuscleIntensity calculateFinalIntensity() {
    if (highCount > 0) {
      return MuscleIntensity.high;
    }

    if (mediumCount >= 2) {
      return MuscleIntensity.high;
    }

    if (mediumCount == 1) {
      return MuscleIntensity.medium;
    }

    if (lowCount >= 2) {
      return MuscleIntensity.medium;
    }

    if (lowCount == 1) {
      return MuscleIntensity.low;
    }

    return MuscleIntensity.inactive;
  }
}
