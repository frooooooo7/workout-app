import '../models/training_session.dart';
import '../models/training_summary_stats.dart';
import 'training_session_detail_mapper.dart';

/// Czyste agregacje podsumowania treningów — bez I/O, łatwe do testowania.
abstract final class TrainingSummaryCalculator {
  /// Poniedziałek 00:00 czasu lokalnego w tygodniu [now].
  static DateTime startOfWeek(DateTime now) {
    final local = now.toLocal();
    // Konstruktor normalizuje „ujemne” dni i nie gubi godziny przy zmianie
    // czasu (w przeciwieństwie do odejmowania `Duration`).
    return DateTime(local.year, local.month, local.day - (local.weekday - 1));
  }

  /// Pierwszy dzień miesiąca 00:00 czasu lokalnego.
  static DateTime startOfMonth(DateTime now) {
    final local = now.toLocal();
    return DateTime(local.year, local.month);
  }

  /// Najwcześniejsza data potrzebna do obu okresów (tydzień może zaczynać się
  /// w poprzednim miesiącu).
  static DateTime earliestStart(DateTime now) {
    final week = startOfWeek(now);
    final month = startOfMonth(now);
    return week.isBefore(month) ? week : month;
  }

  static TrainingSummary summarize(
    Iterable<TrainingSession> sessions, {
    required DateTime now,
  }) {
    final weekStart = startOfWeek(now);
    final monthStart = startOfMonth(now);
    final week = <TrainingSession>[];
    final month = <TrainingSession>[];

    for (final session in sessions) {
      if (session.status != TrainingSessionStatus.completed) continue;
      final started = session.startedAt;
      if (started.isAfter(now)) continue;
      if (!started.isBefore(weekStart)) week.add(session);
      if (!started.isBefore(monthStart)) month.add(session);
    }

    return TrainingSummary(week: aggregate(week), month: month.isEmpty
        ? TrainingPeriodStats.empty
        : aggregate(month));
  }

  /// Liczy wyłącznie ukończone serie; ciężar i powtórzenia z wykonania
  /// (tekst z klawiatury: `82,5`, `82.5`, `8`). Seria bez kompletu liczb
  /// dokłada się do liczby serii, ale nie do objętości.
  static TrainingPeriodStats aggregate(Iterable<TrainingSession> sessions) {
    var workouts = 0;
    var durationSec = 0;
    var completedSets = 0;
    var reps = 0;
    var volumeKg = 0.0;
    final exerciseKeys = <String>{};

    for (final session in sessions) {
      if (session.status != TrainingSessionStatus.completed) continue;
      workouts++;
      final finishedAt = session.finishedAt;
      if (finishedAt != null) {
        final seconds = finishedAt.difference(session.startedAt).inSeconds;
        if (seconds > 0) durationSec += seconds;
      }

      for (final exercise in session.exercises) {
        var hasCompletedSet = false;
        for (final set in exercise.sets) {
          if (!set.completed) continue;
          hasCompletedSet = true;
          completedSets++;
          final setReps = parseReps(set.actualReps);
          if (setReps == null) continue;
          reps += setReps;
          final weight = parseWeightKg(set.actualWeight);
          if (weight != null) volumeKg += weight * setReps;
        }
        if (hasCompletedSet) exerciseKeys.add(_exerciseKey(exercise));
      }
    }

    return TrainingPeriodStats(
      workouts: workouts,
      durationSec: durationSec,
      completedSets: completedSets,
      reps: reps,
      volumeKg: volumeKg,
      distinctExercises: exerciseKeys.length,
    );
  }

  static String _exerciseKey(TrainingSessionExercise exercise) {
    final id = exercise.exerciseId.trim();
    if (id.isNotEmpty) return 'id:$id';
    return 'name:${exercise.exerciseName.trim().toLowerCase()}';
  }
}
