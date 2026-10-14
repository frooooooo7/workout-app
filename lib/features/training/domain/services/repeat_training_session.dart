import '../models/training_session.dart';

/// Nowa aktywna sesja na wzór [source] („Powtórz trening”):
///
/// * te same ćwiczenia w tej samej kolejności (snapshot nazwy, mięśni,
///   kategorii i obrazka) i ta sama liczba serii, z zachowanym rodzajem
///   każdej (rozgrzewka zostaje rozgrzewką),
/// * wartości planowane = poprzednie wykonanie, a gdy go brak — poprzedni
///   plan; pola wykonania są nimi wstępnie wypełnione (jak przy starcie
///   z planu), serie nieukończone,
/// * nowe identyfikatory sesji, ćwiczeń i serii; bez notatki sesji ani
///   notatek do ćwiczeń i bez udostępnienia na profilu,
/// * powiązanie z planem tylko wtedy, gdy plan nadal istnieje ([planLocalId]
///   / [planServerId] podaje wywołujący), nazwa, kolor i ikona zostają
///   zawsze, podobnie przerwy i superserie ćwiczeń.
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
    planColorKey: source.planColorKey,
    planIconKey: source.planIconKey,
    startedAt: (startedAt ?? DateTime.now()).toUtc(),
    exercises: [
      for (final exercise in source.exercises)
        TrainingSessionExercise(
          exerciseId: exercise.exerciseId,
          exerciseName: exercise.exerciseName,
          exerciseMuscles: List<String>.of(exercise.exerciseMuscles),
          exerciseCategory: exercise.exerciseCategory,
          exerciseImageUrl: exercise.exerciseImageUrl,
          restSeconds: exercise.restSeconds,
          supersetGroup: exercise.supersetGroup,
          tracking: exercise.tracking,
          distanceUnit: exercise.distanceUnit,
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
    setType: previous.setType,
    plannedWeight: weight,
    plannedReps: reps ?? '',
    plannedRir: rir,
    plannedTempo: tempo,
    actualWeight: weight,
    actualReps: reps,
    actualRir: rir,
    actualTempo: tempo,
    // Kardio: poprzedni czas i dystans to cel, wynik wpisuje się na nowo.
    plannedDurationSeconds:
        previous.actualDurationSeconds ?? previous.plannedDurationSeconds,
    plannedDistanceM: previous.actualDistanceM ?? previous.plannedDistanceM,
  );
}

String? _preferActual(String? actual, String? planned) {
  final a = actual?.trim();
  if (a != null && a.isNotEmpty) return a;
  final p = planned?.trim();
  if (p != null && p.isNotEmpty) return p;
  return null;
}
