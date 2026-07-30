import '../../library/domain/models/exercise.dart';
import '../models/muscle_highlight.dart';
import '../models/muscle_intensity.dart';

/// Adapter konwertuje między aplikacją MuscleGroup a Body Highlighter slugami
extension MuscleGroupToSlug on MuscleGroup {
  /// Konwertuje MuscleGroup na slug Body Highlighter
  String get bodyHighlighterSlug {
    return switch (this) {
      MuscleGroup.chest => 'chest',
      MuscleGroup.back => 'upper-back', // Plecy = upper-back w Body Highlighter
      MuscleGroup.legs => 'quadriceps', // Nogi = quadriceps (głównie czworogłowe)
      MuscleGroup.shoulders => 'deltoids',
      MuscleGroup.biceps => 'biceps',
      MuscleGroup.triceps => 'triceps',
      MuscleGroup.abs => 'abs',
      MuscleGroup.glutes => 'gluteal',
      MuscleGroup.traps => 'trapezius',
      MuscleGroup.lats => 'upper-back',
      MuscleGroup.rhomboids => 'upper-back',
      MuscleGroup.lowerBack => 'lower-back',
      MuscleGroup.frontDelts => 'deltoids',
      MuscleGroup.sideDelts => 'deltoids',
      MuscleGroup.rearDelts => 'deltoids',
      MuscleGroup.forearms => 'forearm',
      MuscleGroup.obliques => 'obliques',
      MuscleGroup.quads => 'quadriceps',
      MuscleGroup.hamstrings => 'hamstring',
      MuscleGroup.calves => 'calves',
      MuscleGroup.adductors => 'adductors',
      MuscleGroup.all => 'chest',
    };
  }
}

/// Konwertuje intensywność aplikacji (0-1) na MuscleIntensity
MuscleIntensity intensityToMuscleIntensity(double intensity) {
  if (intensity <= 0) return MuscleIntensity.inactive;
  if (intensity <= 0.33) return MuscleIntensity.low;
  if (intensity <= 0.66) return MuscleIntensity.medium;
  return MuscleIntensity.high;
}

/// Batch converter: Map of MuscleGroup to double -> Set of MuscleHighlight
Set<MuscleHighlight> toMuscleHighlights(Map<MuscleGroup, double> intensitiesByMuscle) {
  return {
    for (final entry in intensitiesByMuscle.entries)
      MuscleHighlight(
        muscle: entry.key.bodyHighlighterSlug,
        intensity: intensityToMuscleIntensity(entry.value),
      ),
  };
}
