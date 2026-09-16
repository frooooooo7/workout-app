import '../models/training_session.dart';

/// Formularz edycji zakończonego treningu — surowe wartości z pól.
class WorkoutEditDraft {
  const WorkoutEditDraft({
    required this.name,
    required this.note,
    required this.startedAt,
    required this.durationMinutes,
    required this.exercises,
  });

  final String name;
  final String note;

  /// Początek treningu (dowolna strefa; zapisywany jako UTC).
  final DateTime startedAt;

  /// Czas trwania w minutach, tak jak wpisany.
  final String durationMinutes;
  final List<TrainingSessionExercise> exercises;

  WorkoutEditDraft copyWith({
    String? name,
    String? note,
    DateTime? startedAt,
    String? durationMinutes,
    List<TrainingSessionExercise>? exercises,
  }) {
    return WorkoutEditDraft(
      name: name ?? this.name,
      note: note ?? this.note,
      startedAt: startedAt ?? this.startedAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      exercises: exercises ?? this.exercises,
    );
  }

  factory WorkoutEditDraft.fromSession(TrainingSession session) {
    final finishedAt = session.finishedAt;
    final minutes = finishedAt == null
        ? 0
        : (finishedAt.difference(session.startedAt).inSeconds / 60).round();
    return WorkoutEditDraft(
      name: session.planName,
      note: session.note ?? '',
      startedAt: session.startedAt.toLocal(),
      durationMinutes: '${minutes < 0 ? 0 : minutes}',
      exercises: session.exercises,
    );
  }
}

/// Maksymalny czas treningu przyjmowany w formularzu (24 h).
const maxWorkoutDurationMinutes = 24 * 60;

final _weightPattern = RegExp(r'^\d{1,4}([.,]\d{1,3})?$');
final _intPattern = RegExp(r'^\d{1,4}$');

/// Pierwszy błąd formularza (po polsku) albo `null`, gdy można zapisać.
String? validateWorkoutEdit(WorkoutEditDraft draft, {DateTime? now}) {
  if (draft.name.trim().isEmpty) return 'Podaj nazwę treningu.';
  if (draft.name.trim().length > 120) {
    return 'Nazwa treningu może mieć najwyżej 120 znaków.';
  }
  if (draft.note.trim().length > 2000) {
    return 'Notatka może mieć najwyżej 2000 znaków.';
  }

  final minutes = parseDurationMinutes(draft.durationMinutes);
  if (minutes == null) {
    return 'Czas trwania musi być liczbą minut (0 lub więcej).';
  }
  if (minutes > maxWorkoutDurationMinutes) {
    return 'Czas trwania nie może przekraczać 24 godzin.';
  }
  final clock = now ?? DateTime.now();
  if (draft.startedAt.isAfter(clock.add(const Duration(minutes: 5)))) {
    return 'Data rozpoczęcia nie może być w przyszłości.';
  }

  if (draft.exercises.isEmpty) {
    return 'Trening musi mieć co najmniej jedno ćwiczenie.';
  }
  for (final exercise in draft.exercises) {
    final name = exercise.exerciseName;
    if (exercise.sets.isEmpty) {
      return 'Ćwiczenie „$name” musi mieć co najmniej jedną serię.';
    }
    for (var i = 0; i < exercise.sets.length; i++) {
      final set = exercise.sets[i];
      final label = '„$name”, seria ${i + 1}';
      final weight = set.actualWeight?.trim() ?? '';
      if (weight.isNotEmpty && !_weightPattern.hasMatch(weight)) {
        return 'Nieprawidłowy ciężar: $label.';
      }
      final reps = set.actualReps?.trim() ?? '';
      if (reps.isNotEmpty && !_intPattern.hasMatch(reps)) {
        return 'Liczba powtórzeń musi być liczbą całkowitą: $label.';
      }
      final rir = set.actualRir?.trim() ?? '';
      if (rir.isNotEmpty &&
          (!_intPattern.hasMatch(rir) || int.parse(rir) > 10)) {
        return 'RIR musi być liczbą od 0 do 10: $label.';
      }
    }
  }
  return null;
}

/// `45` → 45; `''`, `-5`, `4.5` → `null`.
int? parseDurationMinutes(String raw) {
  final trimmed = raw.trim();
  if (!RegExp(r'^\d{1,6}$').hasMatch(trimmed)) return null;
  return int.parse(trimmed);
}

/// Nakłada poprawny ([validateWorkoutEdit]) formularz na [original]:
/// id, status, plan, udostępnienie zostają; `finishedAt = startedAt + czas`
/// (więc nigdy nie jest wcześniejszy); znaczniki odhaczenia serii przesuwają
/// się razem z początkiem treningu, a seria nieukończona ich nie ma.
TrainingSession applyWorkoutEdit(
  TrainingSession original,
  WorkoutEditDraft draft,
) {
  final startedAt = draft.startedAt.toUtc();
  final minutes = parseDurationMinutes(draft.durationMinutes) ?? 0;
  final shift = startedAt.difference(original.startedAt);
  final note = draft.note.trim();

  String? clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  return TrainingSession(
    id: original.id,
    serverId: original.serverId,
    planLocalId: original.planLocalId,
    planServerId: original.planServerId,
    planName: draft.name.trim(),
    status: original.status,
    note: note.isEmpty ? null : note,
    startedAt: startedAt,
    finishedAt: startedAt.add(Duration(minutes: minutes)),
    sharedToProfile: original.sharedToProfile,
    pendingOp: original.pendingOp,
    exercises: [
      for (final exercise in draft.exercises)
        exercise.copyWith(
          sets: [
            for (final set in exercise.sets)
              TrainingSessionSet(
                id: set.id,
                plannedWeight: set.plannedWeight,
                plannedReps: set.plannedReps,
                plannedRir: set.plannedRir,
                plannedTempo: set.plannedTempo,
                actualWeight: clean(set.actualWeight)?.replaceAll(',', '.'),
                actualReps: clean(set.actualReps),
                actualRir: clean(set.actualRir),
                actualTempo: clean(set.actualTempo),
                completed: set.completed,
                completedAt: set.completed ? set.completedAt?.add(shift) : null,
              ),
          ],
        ),
    ],
  );
}
