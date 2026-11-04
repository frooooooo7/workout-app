import '../../../library/domain/models/exercise.dart';
import '../models/training_session.dart';

/// Wynik zamiany ćwiczenia w trakcie treningu.
class ExerciseSwapResult {
  const ExerciseSwapResult({
    required this.exercises,
    required this.newExerciseId,
    required this.original,
    required this.oldKept,
  });

  final List<TrainingSessionExercise> exercises;

  /// Id nowego ćwiczenia w sesji (do przejścia na nie).
  final String newExerciseId;

  /// Zastąpione ćwiczenie sprzed zamiany — do „Cofnij”.
  final TrainingSessionExercise original;

  /// `true`, gdy stare ćwiczenie zostało (z zrobionymi seriami).
  final bool oldKept;
}

/// Zamiana ćwiczenia w trakcie treningu.
///
/// Bez zrobionych serii nowe ćwiczenie staje na miejscu starego (z tą samą
/// liczbą serii i superserią). Gdy część serii jest już zrobiona, stare
/// ćwiczenie zostaje tylko z nimi (zrobione serie zostają przy starym), a
/// nowe dostaje resztę zaplanowanych serii i wchodzi zaraz za nim.
///
/// Między ćwiczeniami z powtórzeniami (ciężar × powt. albo same powtórzenia)
/// serie zachowują typ, powtórzenia, RIR i tempo; ciężar jest czyszczony.
/// W inne tryby zapisu (czas, dystans) nowe serie są puste.
abstract final class ExerciseSwap {
  static bool _repsFamily(ExerciseTracking t) =>
      t == ExerciseTracking.weightReps || t == ExerciseTracking.reps;

  static ExerciseSwapResult? apply(
    List<TrainingSessionExercise> exercises,
    String replacedId,
    Exercise replacement,
  ) {
    final index = exercises.indexWhere((e) => e.id == replacedId);
    if (index == -1) return null;
    final old = exercises[index];
    final done = old.sets.where((set) => set.completed).toList();
    final remaining = old.sets.where((set) => !set.completed).toList();

    final carryPlan =
        _repsFamily(old.tracking) && _repsFamily(replacement.tracking);
    final newSets = remaining.isEmpty
        ? [TrainingSessionSet()]
        : [
            for (final set in remaining)
              carryPlan
                  ? TrainingSessionSet(
                      setType: set.setType,
                      plannedReps: set.plannedReps,
                      plannedRir: set.plannedRir,
                      plannedTempo: set.plannedTempo,
                    )
                  : TrainingSessionSet(),
          ];

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
      sets: newSets,
    );

    final result = List<TrainingSessionExercise>.of(exercises);
    if (done.isEmpty) {
      result[index] = created;
    } else {
      result[index] = old.copyWith(sets: done);
      result.insert(index + 1, created);
    }
    return ExerciseSwapResult(
      exercises: result,
      newExerciseId: created.id,
      original: old,
      oldKept: done.isNotEmpty,
    );
  }

  /// „Cofnij”: cofa tylko zamianę — serie odhaczone w międzyczasie gdziekolwiek
  /// zostają. `null`, gdy nowego ćwiczenia już nie ma w sesji.
  static List<TrainingSessionExercise>? undo(
    List<TrainingSessionExercise> current,
    ExerciseSwapResult swap,
  ) {
    final newIndex = current.indexWhere((e) => e.id == swap.newExerciseId);
    if (newIndex == -1) return null;
    final result = List<TrainingSessionExercise>.of(current);
    if (!swap.oldKept) {
      result[newIndex] = swap.original;
      return result;
    }
    result.removeAt(newIndex);
    final oldIndex = result.indexWhere((e) => e.id == swap.original.id);
    if (oldIndex == -1) {
      result.insert(newIndex, swap.original);
      return result;
    }
    final old = result[oldIndex];
    final haveIds = {for (final s in old.sets) s.id};
    result[oldIndex] = old.copyWith(
      sets: [
        ...old.sets,
        for (final s in swap.original.sets)
          if (!s.completed && !haveIds.contains(s.id)) s,
      ],
    );
    return result;
  }
}
