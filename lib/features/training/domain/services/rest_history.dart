import '../models/training_session.dart';

/// Średnia przerwa między seriami ćwiczenia z ostatnich treningów — z godzin
/// odhaczenia kolejnych serii. Podpowiedź w arkuszu „Przerwa po serii”.
abstract final class RestHistory {
  /// Krótsze odstępy to raczej odhaczanie serii po fakcie, dłuższe — zmiana
  /// ćwiczenia albo pauza; jedne i drugie zaniżałyby / zawyżały średnią.
  static const _minGap = Duration(seconds: 15);
  static const _maxGap = Duration(minutes: 10);

  /// Średnia w sekundach (zaokrąglona do 5 s) z [lastSessions] ostatnich
  /// treningów z tym ćwiczeniem; `null`, gdy nie ma z czego liczyć.
  static ({int seconds, int sessions})? average(
    List<TrainingSession> history, {
    required String exerciseId,
    required String exerciseName,
    int lastSessions = 5,
  }) {
    final name = exerciseName.trim().toLowerCase();
    final sorted = history.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final gaps = <int>[];
    var sessions = 0;
    for (final session in sorted) {
      if (sessions >= lastSessions) break;
      var counted = false;
      for (final exercise in session.exercises) {
        // Sesja pobrana z serwera zna ćwiczenie po id serwera, a plan po
        // lokalnym — nazwa łączy oba przypadki.
        final matches =
            exercise.exerciseId == exerciseId ||
            exercise.exerciseName.trim().toLowerCase() == name;
        if (!matches) continue;
        final times = [
          for (final set in exercise.sets)
            if (set.completed && set.completedAt != null) set.completedAt!,
        ]..sort();
        for (var i = 1; i < times.length; i++) {
          final gap = times[i].difference(times[i - 1]);
          if (gap < _minGap || gap > _maxGap) continue;
          gaps.add(gap.inSeconds);
          counted = true;
        }
      }
      if (counted) sessions++;
    }
    if (gaps.isEmpty) return null;
    final mean = gaps.reduce((a, b) => a + b) / gaps.length;
    return (seconds: (mean / 5).round() * 5, sessions: sessions);
  }

  /// Propozycja przerwy: średnia w górę do pełnych 15 s (2:40 → 2:45).
  static int suggestion(int averageSeconds) =>
      ((averageSeconds + 14) ~/ 15) * 15;
}
