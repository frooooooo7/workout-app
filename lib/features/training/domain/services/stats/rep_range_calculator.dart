import '../../models/training_session.dart';
import '../../models/training_stats.dart';
import 'stats_sets.dart';

/// Ile ukończonych serii przypada na zakresy powtórzeń: siła (1–5), masa
/// (6–12) i wytrzymałość (13+). Serie bez podanej liczby powtórzeń pomijamy.
abstract final class RepRangeCalculator {
  static RepRangeDistribution compute(Iterable<TrainingSession> sessions) {
    var strength = 0;
    var hypertrophy = 0;
    var endurance = 0;
    for (final session in sessions) {
      if (session.status != TrainingSessionStatus.completed) continue;
      for (final exercise in session.exercises) {
        for (final set in completedSetsOf(exercise)) {
          final reps = set.reps;
          if (reps == null || reps <= 0) continue;
          switch (RepRange.of(reps)) {
            case RepRange.strength:
              strength++;
            case RepRange.hypertrophy:
              hypertrophy++;
            case RepRange.endurance:
              endurance++;
          }
        }
      }
    }
    return RepRangeDistribution(
      strength: strength,
      hypertrophy: hypertrophy,
      endurance: endurance,
    );
  }
}
