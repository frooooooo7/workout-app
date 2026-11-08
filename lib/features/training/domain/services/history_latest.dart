import '../models/training_session.dart';
import 'history_feed_builder.dart';
import 'workout_comparison.dart';

/// Najnowszy trening z listy Historii razem z porównaniem do poprzedniego —
/// dane karty „Ostatni trening” na górze ekranu.
class HistoryLatest {
  const HistoryLatest({required this.entry, this.comparison});

  final HistoryFeedEntry entry;

  /// Ten sam wynik co karta „Porównanie z poprzednim” w podsumowaniu treningu.
  /// `null` — lista z serwera (bez ćwiczeń) albo nie ma z czym porównać.
  final WorkoutComparison? comparison;

  /// Porównanie ćwiczenia z linii karty; `null`, gdy go nie ma.
  ExerciseComparison? comparisonOf(HistoryFeedLine line) {
    final exercises = comparison?.exercises;
    if (exercises == null || line.key.isEmpty) return null;
    for (final exercise in exercises) {
      if (exercise.key == line.key) return exercise;
    }
    return null;
  }
}

/// Układa kartę „Ostatni trening” z najnowszej pozycji [entries] (od
/// najnowszej). `null`, gdy lista jest pusta. Błąd porównania nie psuje listy —
/// karta po prostu jest bez zmian.
HistoryLatest? buildHistoryLatest(
  Iterable<TrainingSession> sessions,
  List<HistoryFeedEntry> entries,
) {
  if (entries.isEmpty) return null;
  final entry = entries.first;
  TrainingSession? latest;
  for (final session in sessions) {
    if (session.id == entry.item.id) {
      latest = session;
      break;
    }
  }
  WorkoutComparison? comparison;
  if (latest != null) {
    try {
      comparison = compareWithPrevious(latest, sessions);
    } on Object {
      comparison = null;
    }
  }
  return HistoryLatest(entry: entry, comparison: comparison);
}
