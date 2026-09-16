import '../models/training_session.dart';

/// Nowa aktywna sesja na wzór [source] („Powtórz trening”):
///
/// * te same ćwiczenia w tej samej kolejności (snapshot nazwy, mięśni,
///   kategorii i obrazka) i ta sama liczba serii,
/// * wartości planowane = poprzednie wykonanie, a gdy go brak — poprzedni
///   plan; pola wykonania są nimi wstępnie wypełnione (jak przy starcie
///   z planu), serie nieukończone,
/// * nowe identyfikatory sesji, ćwiczeń i serii; bez notatki i bez
///   udostępnienia na profilu,
/// * powiązanie z planem tylko wtedy, gdy plan nadal istnieje ([planLocalId]
///   / [planServerId] podaje wywołujący), nazwa zostaje zawsze.
TrainingSession buildRepeatedSession(
  TrainingSession source, {
  String? planLocalId,
  String? planServerId,
  DateTime? startedAt,
}) {
  return TrainingSession(
    planLocalId: planLocalId,
    planServerId: planServerId,
    planName: source.planName,
    startedAt: (startedAt ?? DateTime.now()).toUtc(),
    exercises: [
      for (final exercise in source.exercises)
        TrainingSessionExercise(
          exerciseId: exercise.exerciseId,
          exerciseName: exercise.exerciseName,
          exerciseMuscles: List<String>.of(exercise.exerciseMuscles),
          exerciseCategory: exercise.exerciseCategory,
          exerciseImageUrl: exercise.exerciseImageUrl,
          sets: [for (final set in exercise.sets) _repeatSet(set)],
        ),
    ],
  );
}

TrainingSessionSet _repeatSet(TrainingSessionSet previous) {
  final weight = _preferActual(previous.actualWeight, previous.plannedWeight);
  final reps = _preferActual(previous.actualReps, previous.plannedReps);
  final rir = _preferActual(previous.actualRir, previous.plannedRir);
  final tempo = _preferActual(previous.actualTempo, previous.plannedTempo);
  return TrainingSessionSet(
    plannedWeight: weight,
    plannedReps: reps ?? '',
    plannedRir: rir,
    plannedTempo: tempo,
    actualWeight: weight,
    actualReps: reps,
    actualRir: rir,
    actualTempo: tempo,
  );
}

String? _preferActual(String? actual, String? planned) {
  final a = actual?.trim();
  if (a != null && a.isNotEmpty) return a;
  final p = planned?.trim();
  if (p != null && p.isNotEmpty) return p;
  return null;
}
