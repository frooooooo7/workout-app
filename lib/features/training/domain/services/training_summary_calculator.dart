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

  /// Górna granica czasu jednej sesji. Dłuższa oznacza niemal na pewno
  /// zapomniane „Zakończ” — żaden trening nie trwa pół dnia.
  static const maxSessionSec = 5 * 3600;

  /// Zapas po ostatniej ukończonej serii: rozciąganie, prysznic na siłowni,
  /// chwila zanim ktoś naciśnie „Zakończ”.
  static const _finishPaddingSec = 10 * 60;

  /// Od takiej przerwy między ostatnią serią a „Zakończ” uznajemy, że sesję
  /// zapomniano zakończyć. Krótsza to zwykłe zakończenie (albo czas wpisany
  /// ręcznie przy edycji treningu) — wtedy wierzymy `finishedAt`.
  static const _forgottenFinishGapSec = 2 * 3600;

  /// Czas trwania ukończonej sesji w sekundach.
  ///
  /// Zwykle to koniec minus początek. Gdy serie mają znaczniki czasu, a
  /// „Zakończ” naciśnięto ponad 2 h po ostatniej z nich (sesja zostawiona na
  /// noc), liczymy do ostatniej serii plus zapas. Bez znaczników (sesje
  /// pobrane z serwera) zostaje tylko górna granica [maxSessionSec].
  static int sessionDurationSec(TrainingSession session) {
    final finishedAt = session.finishedAt;
    if (finishedAt == null) return 0;
    var seconds = finishedAt.difference(session.startedAt).inSeconds;
    if (seconds <= 0) return 0;

    DateTime? lastSet;
    var stamped = 0;
    for (final exercise in session.exercises) {
      for (final set in exercise.sets) {
        final at = set.completedAt;
        if (!set.completed || at == null) continue;
        stamped++;
        if (lastSet == null || at.isAfter(lastSet)) lastSet = at;
      }
    }
    // Jedna seria to za mało, by ufać znacznikom (ktoś mógł odhaczyć całość
    // naraz na początku).
    if (lastSet != null &&
        stamped >= 2 &&
        lastSet.isAfter(session.startedAt) &&
        finishedAt.difference(lastSet).inSeconds > _forgottenFinishGapSec) {
      seconds =
          lastSet.difference(session.startedAt).inSeconds + _finishPaddingSec;
    }
    return seconds > maxSessionSec ? maxSessionSec : seconds;
  }

  /// Liczy wyłącznie ukończone serie (bez rozgrzewek); ciężar i powtórzenia
  /// z wykonania (tekst z klawiatury: `82,5`, `82.5`, `8`). Seria bez kompletu
  /// liczb dokłada się do liczby serii, ale nie do objętości.
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
      durationSec += sessionDurationSec(session);

      for (final exercise in session.exercises) {
        var hasCompletedSet = false;
        for (final set in exercise.sets) {
          if (!set.completed || !set.countsTowardStats) continue;
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
