import '../../../training/domain/models/training_session.dart';
import '../../../training/domain/models/training_summary_stats.dart';
import '../../../training/domain/services/stats/weekly_goal_calculator.dart';
import '../../../training/domain/services/training_summary_calculator.dart';

/// Bieżący tydzień na profilu: dni z treningiem, sumy i seria tygodni.
class ProfileWeekSummary {
  const ProfileWeekSummary({
    this.trainedWeekdays = const {},
    this.stats = TrainingPeriodStats.empty,
    this.streakWeeks = 0,
    this.streakByGoal = false,
  });

  /// [DateTime.weekday] (1 = poniedziałek) dni z ukończonym treningiem.
  final Set<int> trainedWeekdays;
  final TrainingPeriodStats stats;

  /// Passa — tak samo jak w Statystykach i kalendarzu: kolejne tygodnie
  /// z wykonanym celem tygodniowym, a bez celu z co najmniej jednym treningiem.
  /// Liczy od bieżącego tygodnia (albo od poprzedniego, gdy bieżący jeszcze
  /// nie spełnia warunku).
  final int streakWeeks;

  /// Czy [streakWeeks] opiera się na celu tygodniowym.
  final bool streakByGoal;

  static const empty = ProfileWeekSummary();
}

abstract final class ProfileWeekCalculator {
  /// Ile tygodni wstecz sprawdzamy serię — dłuższa pokazuje się jako „26+”.
  static const streakLookbackWeeks = 26;

  static DateTime earliestStart(DateTime now) {
    final week = TrainingSummaryCalculator.startOfWeek(now);
    return DateTime(
      week.year,
      week.month,
      week.day - 7 * (streakLookbackWeeks - 1),
    );
  }

  static ProfileWeekSummary summarize(
    Iterable<TrainingSession> sessions, {
    required DateTime now,
    int? goal,
  }) {
    final hasGoal =
        goal != null && goal >= 1 && goal <= WeeklyGoalCalculator.maxGoal;
    final needed = hasGoal ? goal : 1;
    final weekStart = TrainingSummaryCalculator.startOfWeek(now);
    final thisWeek = <TrainingSession>[];
    final perWeek = <DateTime, int>{};

    for (final session in sessions) {
      if (session.status != TrainingSessionStatus.completed) continue;
      final started = session.startedAt.toLocal();
      if (started.isAfter(now)) continue;
      perWeek.update(
        TrainingSummaryCalculator.startOfWeek(started),
        (v) => v + 1,
        ifAbsent: () => 1,
      );
      if (!started.isBefore(weekStart)) thisWeek.add(session);
    }

    bool met(DateTime week) => (perWeek[week] ?? 0) >= needed;

    var streak = 0;
    var cursor = weekStart;
    if (!met(cursor)) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 7);
    }
    while (met(cursor) && streak < streakLookbackWeeks) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 7);
    }

    return ProfileWeekSummary(
      trainedWeekdays: {
        for (final session in thisWeek) session.startedAt.toLocal().weekday,
      },
      stats: TrainingSummaryCalculator.aggregate(thisWeek),
      streakWeeks: streak,
      streakByGoal: hasGoal,
    );
  }
}
