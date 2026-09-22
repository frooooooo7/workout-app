import '../../../training/domain/models/training_session.dart';
import '../../../training/domain/models/training_summary_stats.dart';
import '../../../training/domain/services/training_summary_calculator.dart';

/// Bieżący tydzień na profilu: dni z treningiem, sumy i seria tygodni.
class ProfileWeekSummary {
  const ProfileWeekSummary({
    this.trainedWeekdays = const {},
    this.stats = TrainingPeriodStats.empty,
    this.streakWeeks = 0,
  });

  /// [DateTime.weekday] (1 = poniedziałek) dni z ukończonym treningiem.
  final Set<int> trainedWeekdays;
  final TrainingPeriodStats stats;

  /// Kolejne tygodnie z co najmniej jednym treningiem, licząc od bieżącego
  /// (albo od poprzedniego, gdy w tym tygodniu jeszcze nie było treningu).
  final int streakWeeks;

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
  }) {
    final weekStart = TrainingSummaryCalculator.startOfWeek(now);
    final thisWeek = <TrainingSession>[];
    final weeksWithWorkout = <DateTime>{};

    for (final session in sessions) {
      if (session.status != TrainingSessionStatus.completed) continue;
      final started = session.startedAt.toLocal();
      if (started.isAfter(now)) continue;
      weeksWithWorkout.add(TrainingSummaryCalculator.startOfWeek(started));
      if (!started.isBefore(weekStart)) thisWeek.add(session);
    }

    var streak = 0;
    var cursor = weekStart;
    if (!weeksWithWorkout.contains(cursor)) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 7);
    }
    while (weeksWithWorkout.contains(cursor) && streak < streakLookbackWeeks) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 7);
    }

    return ProfileWeekSummary(
      trainedWeekdays: {
        for (final session in thisWeek) session.startedAt.toLocal().weekday,
      },
      stats: TrainingSummaryCalculator.aggregate(thisWeek),
      streakWeeks: streak,
    );
  }
}
