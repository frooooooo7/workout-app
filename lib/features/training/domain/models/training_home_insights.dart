import 'training_stats.dart';

/// Najlepsza seria ćwiczenia z ostatniego treningu, w którym je wykonano —
/// kolumna „Ostatnio” w karcie dzisiejszego planu.
class ExerciseLastResult {
  const ExerciseLastResult({this.weightKg, this.reps});

  /// `null` — seria z masą własną.
  final double? weightKg;
  final int? reps;
}

/// Dane ekranu startowego „Trening” policzone z lokalnej historii: stan dni
/// bieżącego tygodnia, ostatnie wyniki i rekordy ćwiczeń, typowy czas planu
/// oraz cel tygodniowy.
class TrainingHomeInsights {
  const TrainingHomeInsights({
    this.weekDonePlans = const {},
    this.weekDoneKeys = const {},
    this.lastResults = const {},
    this.bests = const {},
    this.planDurationsSec = const {},
    this.recordsBySession = const {},
    this.weeklyGoal,
  });

  /// Dzień tygodnia (1–7) → nazwa planu ukończonego tego dnia treningu.
  final Map<int, String> weekDonePlans;

  /// Dzień tygodnia (1–7) → klucze **wszystkich** planów ukończonych tego
  /// dnia ([donePlanKeys]); [weekDonePlans] trzyma tylko ostatni trening.
  final Map<int, Set<String>> weekDoneKeys;

  /// Klucz ćwiczenia ([homeExerciseKey]) → ostatni wynik.
  final Map<String, ExerciseLastResult> lastResults;

  /// Klucz ćwiczenia → najlepsze wyniki z całej historii.
  final Map<String, ExerciseBest> bests;

  /// Nazwa planu (małymi literami) → typowy czas treningu w sekundach.
  final Map<String, int> planDurationsSec;

  /// Identyfikator sesji (lokalny i serwerowy) → liczba pobitych rekordów.
  final Map<String, int> recordsBySession;

  /// `null`, gdy cel w profilu nie jest ustawiony albo brak sieci.
  final WeeklyGoalProgress? weeklyGoal;

  static const empty = TrainingHomeInsights();

  /// Czy plan o podanych identyfikatorach i nazwie był ukończony w [weekday]
  /// (dowolnym z treningów tego dnia). Najpierw po identyfikatorze, więc
  /// zmiana nazwy planu nie psuje stanu; nazwa tylko dla sesji bez id.
  bool isPlanDone(
    int weekday, {
    required Iterable<String?> planIds,
    required String planName,
  }) {
    final keys = weekDoneKeys[weekday];
    if (keys == null || keys.isEmpty) return false;
    for (final id in planIds) {
      if (id != null && id.isNotEmpty && keys.contains('id:$id')) return true;
    }
    return keys.contains(_nameKey(planName));
  }

  int? durationFor(String planName) =>
      planDurationsSec[planName.trim().toLowerCase()];
}

/// Klucz ćwiczenia zgodny ze `statsExerciseKey` — po nazwie, bo sesje
/// z serwera i lokalne mają różne identyfikatory tego samego ćwiczenia.
String homeExerciseKey(String exerciseName, String exerciseId) {
  final name = exerciseName.trim().toLowerCase();
  if (name.isNotEmpty) return 'name:$name';
  return 'id:${exerciseId.trim()}';
}

String _nameKey(String name) => 'name:${name.trim().toLowerCase()}';

/// Klucze, po których ukończony trening wskazuje swój plan: identyfikatory
/// planu (lokalny i serwerowy), a dla starych sesji bez nich — nazwa. Wolny
/// trening nie ma kluczy, więc nie zlewa się z planem o tej samej nazwie.
Set<String> donePlanKeys({
  required String? planLocalId,
  required String? planServerId,
  required String planName,
  required String customName,
}) {
  final keys = <String>{
    for (final id in [planLocalId, planServerId])
      if (id != null && id.isNotEmpty) 'id:$id',
  };
  if (keys.isEmpty &&
      planName.trim().toLowerCase() != customName.toLowerCase()) {
    keys.add(_nameKey(planName));
  }
  return keys;
}
