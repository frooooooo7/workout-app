import '../../library/domain/models/exercise.dart';
import '../domain/models/training_history_models.dart';

/// Wspólny parser ćwiczenia z serią — ten sam kształt zwraca historia
/// (`GET /api/v1/training-history/:id`) i szczegóły posta w feedzie
/// (`GET /posts/:id`). Historia podaje mięśnie jako `muscles`, feed jako
/// `exerciseMuscles` — obsługujemy oba klucze.
TrainingExerciseDetail trainingExerciseDetailFromJson(
  Map<String, dynamic> json,
) {
  final setsRaw = json['sets'] as List? ?? const [];
  final musclesRaw =
      (json['muscles'] ?? json['exerciseMuscles']) as List? ?? const [];
  return TrainingExerciseDetail(
    exerciseId: json['exerciseId'] as String? ?? '',
    exerciseName: json['exerciseName'] as String? ?? 'Ćwiczenie',
    muscles: musclesRaw
        .map((raw) => MuscleGroup.tryParse(raw is String ? raw : null))
        .whereType<MuscleGroup>()
        .toList(growable: false),
    imageUrl: json['imageUrl'] as String?,
    sets: setsRaw
        .whereType<Map<String, dynamic>>()
        .map(trainingExerciseSetDetailFromJson)
        .toList(growable: false),
  );
}

TrainingExerciseSetDetail trainingExerciseSetDetailFromJson(
  Map<String, dynamic> json,
) {
  return TrainingExerciseSetDetail(
    setIndex: (json['setIndex'] as num?)?.toInt() ?? 0,
    planned: trainingSetMetricsFromJson(
      json['planned'] as Map<String, dynamic>?,
    ),
    actual: trainingSetMetricsFromJson(json['actual'] as Map<String, dynamic>?),
    completed: json['completed'] as bool? ?? false,
    completedAt: DateTime.tryParse(
      json['completedAt'] as String? ?? '',
    )?.toUtc(),
  );
}

TrainingSetMetrics? trainingSetMetricsFromJson(Map<String, dynamic>? json) {
  if (json == null) return null;
  return TrainingSetMetrics(
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    reps: (json['reps'] as num?)?.toInt(),
    rir: (json['rir'] as num?)?.toInt(),
    tempo: json['tempo'] as String?,
  );
}
