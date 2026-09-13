import '../../../library/domain/models/exercise.dart';
import '../models/training_history_models.dart';
import '../models/training_session.dart';

/// Przekłada lokalną, właśnie ukończoną [TrainingSession] na model odczytu
/// [TrainingSessionDetail], którym operują widoki historii (metryki, mapa
/// mięśni, formatery).
///
/// Dzięki temu ekran podsumowania pokazuje te same liczby, które użytkownik
/// zobaczy później w historii — bez czekania na synchronizację z serwerem.
TrainingSessionDetail trainingSessionDetailFromSession(TrainingSession session) {
  final endedAt = session.finishedAt;
  final durationSec = endedAt == null
      ? 0
      : endedAt.difference(session.startedAt).inSeconds.clamp(0, 1 << 31);

  return TrainingSessionDetail(
    id: session.serverId ?? session.id,
    startedAt: session.startedAt,
    endedAt: endedAt,
    durationSec: durationSec,
    status: session.status,
    plan: TrainingPlanSummary(
      id: session.planServerId ?? session.planLocalId ?? '',
      name: session.planName,
    ),
    note: session.note,
    exercises: session.exercises
        .map(_exerciseDetailFromSession)
        .toList(growable: false),
    updatedAt: endedAt ?? session.startedAt,
    sharedToProfile: session.sharedToProfile,
  );
}

TrainingExerciseDetail _exerciseDetailFromSession(
  TrainingSessionExercise exercise,
) {
  return TrainingExerciseDetail(
    exerciseId: exercise.exerciseId,
    exerciseName: exercise.exerciseName,
    muscles: exercise.exerciseMuscles
        .map(MuscleGroup.tryParse)
        .whereType<MuscleGroup>()
        .toList(growable: false),
    imageUrl: exercise.exerciseImageUrl,
    sets: exercise.sets
        .asMap()
        .entries
        .map(
          (entry) => TrainingExerciseSetDetail(
            setIndex: entry.key,
            planned: _metricsFromRaw(
              weight: entry.value.plannedWeight,
              reps: entry.value.plannedReps,
              rir: entry.value.plannedRir,
              tempo: entry.value.plannedTempo,
            ),
            actual: _metricsFromRaw(
              weight: entry.value.actualWeight,
              reps: entry.value.actualReps,
              rir: entry.value.actualRir,
              tempo: entry.value.actualTempo,
            ),
            completed: entry.value.completed,
            completedAt: entry.value.completedAt,
          ),
        )
        .toList(growable: false),
  );
}

/// Serie trzymają surowy tekst z klawiatury (`82,5`, `8-10`, ` 60 `),
/// więc do metryk trafiają tylko wartości dające się jednoznacznie sparsować.
TrainingSetMetrics? _metricsFromRaw({
  String? weight,
  String? reps,
  String? rir,
  String? tempo,
}) {
  final weightKg = parseWeightKg(weight);
  final repsCount = parseReps(reps);
  final rirValue = parseReps(rir);
  final tempoValue = tempo?.trim();
  final hasTempo = tempoValue != null && tempoValue.isNotEmpty;
  if (weightKg == null && repsCount == null && rirValue == null && !hasTempo) {
    return null;
  }
  return TrainingSetMetrics(
    weightKg: weightKg,
    reps: repsCount,
    rir: rirValue,
    tempo: hasTempo ? tempoValue : null,
  );
}

/// `82,5` → 82.5; `60 kg` → 60; `''` / `abc` → `null`.
double? parseWeightKg(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.trim().replaceAll(',', '.').replaceAll(
    RegExp(r'[^0-9.]'),
    '',
  );
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// `8` → 8; `10 powt.` → 10; zakres `8-10` zostaje `null`, bo nie jest
/// pojedynczą liczbą wykonanych powtórzeń.
int? parseReps(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty || RegExp(r'\d\s*[-–]\s*\d').hasMatch(trimmed)) {
    return null;
  }
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}
