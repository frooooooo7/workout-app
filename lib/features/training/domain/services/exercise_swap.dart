import '../../../library/domain/models/exercise.dart';
import '../models/training_session.dart';

/// Wynik zamiany ćwiczenia w trakcie treningu.
class ExerciseSwapResult {
  const ExerciseSwapResult({
    required this.exercises,
    required this.newExerciseId,
  });

  final List<TrainingSessionExercise> exercises;

  /// Id nowego ćwiczenia w sesji (do przejścia na nie).
  final String newExerciseId;
}

/// Zamiana ćwiczenia w trakcie treningu.
///
/// Bez zrobionych serii nowe ćwiczenie staje na miejscu starego (z tą samą
/// liczbą serii i superserią). Gdy część serii jest już zrobiona, stare
/// ćwiczenie zostaje tylko z nimi (zrobione serie zostają przy starym), a
/// nowe dostaje resztę zaplanowanych serii i wchodzi zaraz za nim.
abstract final class ExerciseSwap {
  static ExerciseSwapResult? apply(
    List<TrainingSessionExercise> exercises,
    String replacedId,
    Exercise replacement,
  ) {
    final index = exercises.indexWhere((e) => e.id == replacedId);
    if (index == -1) return null;
    final old = exercises[index];
    final done = old.sets.where((set) => set.completed).toList();
    final planned = old.sets.length;
    final newSetCount = done.isEmpty
        ? (planned < 1 ? 1 : planned)
        : (planned - done.length < 1 ? 1 : planned - done.length);

    final created = TrainingSessionExercise(
      exerciseId: replacement.id,
      exerciseName: replacement.name,
      exerciseMuscles: replacement.muscles.map((m) => m.name).toList(),
      exerciseCategory: replacement.category.name,
      exerciseImageUrl: replacement.imageUrl,
      tracking: replacement.tracking,
      distanceUnit: replacement.distanceUnit,
      supersetGroup: old.supersetGroup,
      restSeconds: old.restSeconds,
      sets: [for (var i = 0; i < newSetCount; i++) TrainingSessionSet()],
    );

    final result = List<TrainingSessionExercise>.of(exercises);
    if (done.isEmpty) {
      result[index] = created;
    } else {
      result[index] = old.copyWith(sets: done);
      result.insert(index + 1, created);
    }
    return ExerciseSwapResult(exercises: result, newExerciseId: created.id);
  }
}
