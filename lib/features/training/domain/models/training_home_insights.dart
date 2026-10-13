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
    this.lastResults = const {},
    this.bests = const {},
    this.planDurationsSec = const {},
    this.recordsBySession = const {},
    this.weeklyGoal,
  });

  /// Dzień tygodnia (1–7) → nazwa planu ukończonego tego dnia treningu.
  final Map<int, String> weekDonePlans;

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
