import '../../models/training_session.dart';
import '../../models/training_stats.dart';
import '../training_summary_calculator.dart';

/// Postęp względem celu tygodniowego z profilu.
abstract final class WeeklyGoalCalculator {
  /// Ile ostatnich tygodni pokazuje karta celu.
  static const weeksShown = 8;

  /// Cel z profilu to „ile razy w tygodniu”; wyżej niż 14 to ewidentnie błąd
  /// danych, a nie plan treningowy.
  static const maxGoal = 14;

  static DateTime _previousWeek(DateTime week) =>
      DateTime(week.year, week.month, week.day - 7);

  /// `null`, gdy cel nie jest ustawiony albo jest nieprawidłowy.
  static WeeklyGoalProgress? compute(
    Iterable<TrainingSession> completed, {
    required DateTime today,
    required int? goal,
  }) {
    if (goal == null || goal < 1 || goal > maxGoal) return null;

    final perWeek = <DateTime, int>{};
    for (final session in completed) {
      final week = TrainingSummaryCalculator.startOfWeek(
        session.startedAt.toLocal(),
      );
      perWeek.update(week, (v) => v + 1, ifAbsent: () => 1);
    }

    final thisWeek = TrainingSummaryCalculator.startOfWeek(today);
    bool met(DateTime week) => (perWeek[week] ?? 0) >= goal;

    var streak = 0;
    var cursor = thisWeek;
    // Bieżący tydzień jeszcze trwa — jego niewykonany cel nie przerywa serii.
    if (!met(cursor)) cursor = _previousWeek(cursor);
    while (met(cursor)) {
      streak++;
      cursor = _previousWeek(cursor);
    }

    var best = 0;
    for (final week in perWeek.keys) {
      if (!met(week) || met(_previousWeek(week))) continue; // początek serii
      var length = 0;
      var w = week;
      while (met(w)) {
        length++;
        w = DateTime(w.year, w.month, w.day + 7);
      }
      if (length > best) best = length;
    }

    final weeks = <GoalWeek>[];
    for (var i = weeksShown - 1; i >= 0; i--) {
      final start = DateTime(
        thisWeek.year,
        thisWeek.month,
        thisWeek.day - 7 * i,
      );
      weeks.add(GoalWeek(start: start, workouts: perWeek[start] ?? 0));
    }

    return WeeklyGoalProgress(
      goal: goal,
      workoutsThisWeek: perWeek[thisWeek] ?? 0,
      weeks: List.unmodifiable(weeks),
      streakWeeks: streak,
      bestStreakWeeks: best,
      daysLeft: 7 - today.weekday,
    );
  }
}
