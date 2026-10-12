import '../models/training_home_insights.dart';
import '../models/training_session.dart';
import 'stats/personal_records_calculator.dart';
import 'stats/stats_sets.dart';
import 'stats/weekly_goal_calculator.dart';
import 'training_summary_calculator.dart';

/// Liczy [TrainingHomeInsights] z ukończonych sesji — bez I/O.
abstract final class TrainingHomeCalculator {
  /// Z ilu ostatnich treningów planu liczymy typowy czas.
  static const durationSampleSize = 3;

  static TrainingHomeInsights compute(
    Iterable<TrainingSession> sessions, {
    required DateTime today,
    int? weeklyGoal,
  }) {
    final completed = [
      for (final s in sessions)
        if (s.status == TrainingSessionStatus.completed &&
            !s.startedAt.isAfter(today))
          s,
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    final weekStart = TrainingSummaryCalculator.startOfWeek(today);
    final weekDone = <int, String>{};
    final lastResults = <String, ExerciseLastResult>{};
    final durationSamples = <String, List<int>>{};

    // Od najnowszej: pierwsze trafienie to ostatni wynik / ostatni trening dnia.
    for (final session in completed) {
      final local = session.startedAt.toLocal();
      if (!local.isBefore(weekStart)) {
        weekDone.putIfAbsent(local.weekday, () => session.planName);
      }

      final samples = durationSamples.putIfAbsent(
        session.planName.trim().toLowerCase(),
        () => [],
      );
      final duration = TrainingSummaryCalculator.sessionDurationSec(session);
      if (samples.length < durationSampleSize && duration > 0) {
        samples.add(duration);
      }

      for (final exercise in session.exercises) {
        final key = statsExerciseKey(exercise);
        if (lastResults.containsKey(key)) continue;
        final top = _topSet(completedSetsOf(exercise));
        if (top != null) lastResults[key] = top;
      }
    }

    final records = PersonalRecordsCalculator.compute(completed);
    final recordsBySession = <String, int>{};
    for (final record in records.records) {
      recordsBySession.update(
        record.sessionId,
        (v) => v + 1,
        ifAbsent: () => 1,
      );
    }
    // Lista historii przychodzi z serwera — jej sesje mają identyfikator
    // serwerowy, więc liczbę rekordów udostępniamy pod obydwoma.
    for (final session in completed) {
      final count = recordsBySession[session.id];
      final serverId = session.serverId;
      if (count != null && serverId != null) {
        recordsBySession[serverId] = count;
      }
    }

    return TrainingHomeInsights(
      weekDonePlans: weekDone,
      lastResults: lastResults,
      bests: {for (final best in records.bests) best.exerciseKey: best},
      planDurationsSec: {
        for (final entry in durationSamples.entries)
          if (entry.value.isNotEmpty)
            entry.key:
                entry.value.reduce((a, b) => a + b) ~/ entry.value.length,
      },
      recordsBySession: recordsBySession,
      weeklyGoal: WeeklyGoalCalculator.compute(
        completed,
        today: today,
        goal: weeklyGoal,
      ),
    );
  }

  /// Najcięższa seria (przy remisie więcej powtórzeń); bez ciężaru — seria
  /// z największą liczbą powtórzeń.
  static ExerciseLastResult? _topSet(Iterable<CompletedSetValues> sets) {
    CompletedSetValues? weighted;
    CompletedSetValues? bodyweight;
    for (final set in sets) {
      if (set.hasWeight) {
        final best = weighted;
        if (best == null ||
            set.weightKg! > best.weightKg! ||
            (set.weightKg == best.weightKg &&
                (set.reps ?? 0) > (best.reps ?? 0))) {
          weighted = set;
        }
      } else if (set.reps != null &&
          (bodyweight == null || set.reps! > bodyweight.reps!)) {
        bodyweight = set;
      }
    }
    final top = weighted ?? bodyweight;
    if (top == null) return null;
    return ExerciseLastResult(
      weightKg: top.hasWeight ? top.weightKg : null,
      reps: top.reps,
    );
  }
}
