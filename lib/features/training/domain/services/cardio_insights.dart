import '../models/training_session.dart';
import 'stats/stats_sets.dart' show statsExerciseKey;

/// Kardio na ekranie treningu: suma czasu i dystansu odcinków, tempo
/// i najlepsze tempo z historii.

/// Suma czasu (s) i dystansu (m) odcinków.
class CardioTotals {
  const CardioTotals({required this.seconds, required this.meters});

  static const zero = CardioTotals(seconds: 0, meters: 0);

  final int seconds;
  final int meters;

  bool get isEmpty => seconds == 0 && meters == 0;
}

/// Suma odcinków [sets] (z rozgrzewką — to też przebiegnięty dystans).
/// Domyślnie tylko zrobionych; „Razem dziś” liczy też wpisany, jeszcze
/// nieodhaczony odcinek.
CardioTotals cardioTotals(
  Iterable<TrainingSessionSet> sets, {
  bool completedOnly = true,
}) {
  var seconds = 0;
  var meters = 0;
  for (final set in sets) {
    if (completedOnly && !set.completed) continue;
    seconds += set.actualDurationSeconds ?? 0;
    meters += set.actualDistanceM ?? 0;
  }
  return CardioTotals(seconds: seconds, meters: meters);
}

/// `3,2 km · 18:10`, z [withPace] — `… · 5:41 /km`. `null` bez danych.
String? formatCardioTotals(
  CardioTotals totals,
  ExerciseTracking tracking,
  DistanceUnit unit, {
  bool withPace = false,
}) {
  if (totals.isEmpty) return null;
  final parts = [
    if (tracking.tracksDistance && totals.meters > 0)
      unit.formatWithUnit(totals.meters),
    if (totals.seconds > 0) formatSetDuration(totals.seconds),
  ];
  if (withPace && tracking.tracksDistance) {
    final pace = unit.pace(seconds: totals.seconds, meters: totals.meters);
    if (pace != null) parts.add('$pace ${unit.paceSuffix}');
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Tempo odcinka w sekundach na kilometr; `null` bez czasu albo dystansu.
int? paceSecondsPerKm(TrainingSessionSet set) {
  final seconds = set.actualDurationSeconds;
  final meters = set.actualDistanceM;
  if (seconds == null || meters == null || seconds <= 0 || meters <= 0) {
    return null;
  }
  return (seconds * 1000 / meters).round();
}

/// Tempo z sekund na kilometr w jednostce ćwiczenia: `5:38 /km`,
/// `1:52 /500 m`.
String formatPacePerKm(int secondsPerKm, DistanceUnit unit) {
  final seconds = (secondsPerKm * unit.paceMeters / 1000).round();
  return '${formatSetDuration(seconds)} ${unit.paceSuffix}';
}

/// Najlepsze (najszybsze) tempo każdego ćwiczenia z czasem i dystansem
/// w [history] — klucz jak w statystykach ([statsExerciseKey]). Rozgrzewki
/// się nie liczą.
Map<String, int> bestPacesByExercise(Iterable<TrainingSession> history) {
  final best = <String, int>{};
  for (final session in history) {
    if (session.status != TrainingSessionStatus.completed) continue;
    for (final exercise in session.exercises) {
      if (!exercise.tracking.tracksDistance) continue;
      for (final set in exercise.sets) {
        if (!set.completed || !set.countsTowardStats) continue;
        final pace = paceSecondsPerKm(set);
        if (pace == null) continue;
        final key = statsExerciseKey(exercise);
        final current = best[key];
        if (current == null || pace < current) best[key] = pace;
      }
    }
  }
  return best;
}
