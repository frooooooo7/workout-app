import 'models/exercise.dart';

/// Zamienniki ćwiczenia: ten sam ruch albo ten sam mięsień główny, ten sam
/// sposób zapisu serii. Kardio nie patrzy na mięśnie — zamiennikiem są inne
/// ćwiczenia kardio.
abstract final class ExerciseSimilarity {
  /// Do [limit] ćwiczeń z [all] najbardziej podobnych do [exercise], bez niego
  /// samego. Kolejność: ten sam ruch, ten sam mięsień główny, inny sprzęt
  /// przed tym samym (zamiennik ma się czymś różnić), potem alfabetycznie.
  static List<Exercise> substitutes(
    Exercise exercise,
    Iterable<Exercise> all, {
    int limit = 8,
  }) {
    final scored = <(Exercise, int)>[];
    for (final candidate in all) {
      if (_sameExercise(candidate, exercise)) continue;
      if (!_sameTrackingFamily(candidate.tracking, exercise.tracking)) continue;
      final score = _score(exercise, candidate);
      if (score > 0) scored.add((candidate, score));
    }
    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      if (byScore != 0) return byScore;
      return a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase());
    });
    return [for (final (candidate, _) in scored.take(limit)) candidate];
  }

  /// Ciężar × powtórzenia i same powtórzenia to jedna rodzina (pompki mogą
  /// zastąpić wyciskanie); czas i czas z dystansem zostają osobno.
  static bool _sameTrackingFamily(ExerciseTracking a, ExerciseTracking b) {
    bool reps(ExerciseTracking t) =>
        t == ExerciseTracking.weightReps || t == ExerciseTracking.reps;
    return a == b || (reps(a) && reps(b));
  }

  /// Ten sam mięsień główny: 3. Grupa zbiorcza (plecy, nogi, barki) przeciw
  /// konkretnemu mięśniowi z tej grupy (starsze własne ćwiczenia): 1.
  static int _muscleScore(MuscleGroup? a, MuscleGroup? b) {
    if (a == null || b == null) return 0;
    if (a == b) return 3;
    if ((a.isCoarse && b.broadGroup == a) || (b.isCoarse && a.broadGroup == b)) {
      return 1;
    }
    return 0;
  }

  static bool _sameExercise(Exercise a, Exercise b) =>
      a.id == b.id ||
      (a.serverId != null && a.serverId == b.id) ||
      (b.serverId != null && b.serverId == a.id);

  static int _score(Exercise exercise, Exercise candidate) {
    final isCardio = exercise.category == ExerciseCategory.cardio;
    if (isCardio) {
      if (candidate.category != ExerciseCategory.cardio) return 0;
      return candidate.equipment != exercise.equipment ? 2 : 1;
    }
    if (candidate.category == ExerciseCategory.cardio) return 0;

    var score = 0;
    if (exercise.pattern != null && exercise.pattern == candidate.pattern) {
      score += 4;
    }
    score += _muscleScore(
      exercise.workingMuscles.firstOrNull,
      candidate.workingMuscles.firstOrNull,
    );
    if (score == 0) return 0;
    if (exercise.equipment != null && candidate.equipment != exercise.equipment) {
      score += 1;
    }
    return score;
  }
}
