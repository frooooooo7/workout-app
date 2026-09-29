import '../../../../library/domain/models/exercise.dart';
import '../../models/training_session.dart';
import '../training_session_detail_mapper.dart' show parseReps, parseWeightKg;

/// Ukończona seria (bez rozgrzewek) z wartościami rozparsowanymi z tekstu klawiatury. Liczymy
/// wyłącznie wykonanie (`actual*`) — tak jak kafelki historii.
class CompletedSetValues {
  const CompletedSetValues({this.weightKg, this.reps, this.rir});

  /// `null` albo 0 — seria z masą własną.
  final double? weightKg;
  final int? reps;
  final int? rir;

  bool get hasWeight => (weightKg ?? 0) > 0;

  double get volumeKg => hasWeight && reps != null ? weightKg! * reps! : 0;
}

Iterable<CompletedSetValues> completedSetsOf(
  TrainingSessionExercise exercise,
) sync* {
  for (final set in exercise.sets) {
    // Rozgrzewki (SetType.warmup) nie liczą się do serii, objętości ani
    // rekordów — tak samo jak w kafelkach historii i statystykach ćwiczenia.
    if (!set.completed || !set.countsTowardStats) continue;
    yield CompletedSetValues(
      weightKg: parseWeightKg(set.actualWeight),
      reps: parseReps(set.actualReps),
      rir: parseReps(set.actualRir),
    );
  }
}

/// Klucz ćwiczenia w statystykach. Nazwa, a nie id: sesje z serwera niosą
/// identyfikator serwera, a lokalne — lokalny, i to samo ćwiczenie
/// rozpadłoby się na dwa.
String statsExerciseKey(TrainingSessionExercise exercise) {
  final name = exercise.exerciseName.trim().toLowerCase();
  if (name.isNotEmpty) return 'name:$name';
  return 'id:${exercise.exerciseId.trim()}';
}

DateTime statsDay(DateTime local) =>
    DateTime(local.year, local.month, local.day);

/// Grupy mięśni ćwiczenia w kolejności tagów (pierwsza to główna), bez
/// nieznanych nazw i sentinela `all`.
List<MuscleGroup> taggedMuscles(TrainingSessionExercise exercise) => [
  for (final raw in exercise.exerciseMuscles)
    if (MuscleGroup.tryParse(raw) case final m? when m != MuscleGroup.all) m,
];
