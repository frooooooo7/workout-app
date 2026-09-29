import 'dart:math' as math;

import '../../../../library/domain/models/exercise_stats.dart';
import '../../models/training_session.dart';
import '../../models/training_stats.dart';
import '../training_summary_calculator.dart';
import 'muscle_distribution_calculator.dart';
import 'muscle_recovery_calculator.dart';
import 'personal_records_calculator.dart';
import 'rep_range_calculator.dart';
import 'session_records_calculator.dart';
import 'stats_insights_calculator.dart';
import 'stats_sets.dart';
import 'weekly_goal_calculator.dart';

/// Czyste agregacje ekranu statystyk — bez I/O, łatwe do testowania.
abstract final class TrainingStatsCalculator {
  /// Heatmapa pokazuje co najmniej tyle tygodni (krótszy zakres to zbyt mało
  /// kratek, żeby zobaczyć rytm) i najwyżej tyle, ile zmieści się na telefonie.
  static const activityMinWeeks = 12;
  static const activityMaxWeeks = 26;

  /// Wykres progresu sięga co najmniej tyle dni wstecz.
  static const progressMinDays = 90;

  static const topExercisesLimit = 8;

  /// Okno zakresu dla chwili [now]. [earliest] (pierwszy trening) wyznacza
  /// początek zakresu „Całość”.
  static StatsWindow windowFor(
    StatsRange range,
    DateTime now, {
    DateTime? earliest,
    StatsDateRange? custom,
  }) {
    final today = statsDay(now.toLocal());
    final y = today.year;
    final m = today.month;
    final d = today.day;
    final tomorrow = DateTime(y, m, d + 1);

    switch (range) {
      case StatsRange.week:
        return StatsWindow(
          start: DateTime(y, m, d - 6),
          end: tomorrow,
          bucket: StatsBucket.day,
          previousStart: DateTime(y, m, d - 13),
        );
      case StatsRange.month:
        return StatsWindow(
          start: DateTime(y, m, d - 29),
          end: tomorrow,
          bucket: StatsBucket.day,
          previousStart: DateTime(y, m, d - 59),
        );
      case StatsRange.quarter:
        final week = TrainingSummaryCalculator.startOfWeek(today);
        final start = DateTime(week.year, week.month, week.day - 7 * 12);
        final previousStart = DateTime(
          week.year,
          week.month,
          week.day - 7 * 25,
        );
        return StatsWindow(
          start: start,
          end: DateTime(week.year, week.month, week.day + 7),
          bucket: StatsBucket.week,
          previousStart: previousStart,
          previousEnd: _sameElapsed(previousStart, start, tomorrow),
        );
      case StatsRange.year:
        final start = DateTime(y, m - 11);
        final previousStart = DateTime(y, m - 23);
        return StatsWindow(
          start: start,
          end: DateTime(y, m + 1),
          bucket: StatsBucket.month,
          previousStart: previousStart,
          previousEnd: _sameElapsed(previousStart, start, tomorrow),
        );
      case StatsRange.custom:
        final chosen = custom ?? StatsDateRange(DateTime(y, m, d - 29), today);
        final start = chosen.start;
        var end = DateTime(
          chosen.end.year,
          chosen.end.month,
          chosen.end.day + 1,
        );
        if (end.isAfter(tomorrow)) end = tomorrow;
        final length = chosen.days;
        return StatsWindow(
          start: start,
          end: end,
          bucket: length <= 35
              ? StatsBucket.day
              : length <= 26 * 7
              ? StatsBucket.week
              : length <= 36 * 31
              ? StatsBucket.month
              : StatsBucket.year,
          previousStart: DateTime(start.year, start.month, start.day - length),
        );
      case StatsRange.all:
        final weekAgo = DateTime(y, m, d - 6);
        var first = earliest == null ? weekAgo : statsDay(earliest.toLocal());
        if (first.isAfter(weekAgo)) first = weekAgo;
        final spanDays = DateTime.utc(
          y,
          m,
          d,
        ).difference(DateTime.utc(first.year, first.month, first.day)).inDays;
        if (spanDays < 31) {
          return StatsWindow(
            start: first,
            end: tomorrow,
            bucket: StatsBucket.day,
          );
        }
        if (spanDays < 26 * 7) {
          final week = TrainingSummaryCalculator.startOfWeek(today);
          return StatsWindow(
            start: TrainingSummaryCalculator.startOfWeek(first),
            end: DateTime(week.year, week.month, week.day + 7),
            bucket: StatsBucket.week,
          );
        }
        final months = (y - first.year) * 12 + (m - first.month);
        if (months < 36) {
          return StatsWindow(
            start: DateTime(first.year, first.month),
            end: DateTime(y, m + 1),
            bucket: StatsBucket.month,
          );
        }
        return StatsWindow(
          start: DateTime(first.year),
          end: DateTime(y + 1),
          bucket: StatsBucket.year,
        );
    }
  }

  /// Koniec okresu porównawczego: tyle samo dni od [previousStart], ile
  /// upłynęło od [start] do [until]. Okno sięgające w przyszłość (bieżący
  /// tydzień, miesiąc) nie może być porównywane z pełnym poprzednim okresem.
  static DateTime _sameElapsed(
    DateTime previousStart,
    DateTime start,
    DateTime until,
  ) {
    final elapsed = DateTime.utc(
      until.year,
      until.month,
      until.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    final end = DateTime(
      previousStart.year,
      previousStart.month,
      previousStart.day + elapsed,
    );
    return end.isAfter(start) ? start : end;
  }

  /// Początek słupka, do którego należy chwila [local].
  static DateTime bucketStartOf(DateTime local, StatsBucket bucket) =>
      switch (bucket) {
        StatsBucket.day => statsDay(local),
        StatsBucket.week => TrainingSummaryCalculator.startOfWeek(local),
        StatsBucket.month => DateTime(local.year, local.month),
        StatsBucket.year => DateTime(local.year),
      };

  static DateTime nextBucket(DateTime start, StatsBucket bucket) =>
      switch (bucket) {
        StatsBucket.day => DateTime(start.year, start.month, start.day + 1),
        StatsBucket.week => DateTime(start.year, start.month, start.day + 7),
        StatsBucket.month => DateTime(start.year, start.month + 1),
        StatsBucket.year => DateTime(start.year + 1),
      };

  /// Średnia krocząca z [window] ostatnich wartości (łącznie z bieżącą);
  /// `null`, dopóki nie uzbiera się pełne okno.
  static List<double?> trailingAverage(List<double> values, int window) {
    final result = List<double?>.filled(values.length, null);
    var sum = 0.0;
    for (var i = 0; i < values.length; i++) {
      sum += values[i];
      if (i >= window) sum -= values[i - window];
      if (i >= window - 1) result[i] = sum / window;
    }
    return result;
  }

  /// [records] pozwala nie przeliczać rekordów przy każdej zmianie zakresu —
  /// zależą tylko od historii, nie od okna.
  ///
  /// [customRange] jest potrzebny tylko dla [StatsRange.custom]; [weeklyGoal]
  /// to cel z profilu (treningów w tygodniu) albo `null`.
  static TrainingStatsSnapshot compute(
    Iterable<TrainingSession> sessions, {
    required StatsRange range,
    required DateTime now,
    PersonalRecordsResult? records,
    StatsDateRange? customRange,
    int? weeklyGoal,
  }) {
    final completed = <TrainingSession>[];
    DateTime? earliest;
    for (final session in sessions) {
      if (session.status != TrainingSessionStatus.completed) continue;
      if (session.startedAt.isAfter(now)) continue;
      completed.add(session);
      if (earliest == null || session.startedAt.isBefore(earliest)) {
        earliest = session.startedAt;
      }
    }

    final window = windowFor(
      range,
      now,
      earliest: earliest,
      custom: customRange,
    );
    final today = statsDay(now.toLocal());
    final inWindow = <TrainingSession>[];
    final inPrevious = <TrainingSession>[];
    for (final session in completed) {
      final local = session.startedAt.toLocal();
      if (window.contains(local)) {
        inWindow.add(session);
      } else if (window.containsPrevious(local)) {
        inPrevious.add(session);
      }
    }

    final current = TrainingSummaryCalculator.aggregate(inWindow);
    final allRecords = records ?? PersonalRecordsCalculator.compute(completed);
    final windowRecords = <PersonalRecord>[];
    var previousRecords = 0;
    for (final record in allRecords.records.reversed) {
      final local = record.date.toLocal();
      if (window.contains(local)) {
        windowRecords.add(record);
      } else if (window.containsPrevious(local)) {
        previousRecords++;
      }
    }

    final streaks = _streaks(completed, today);
    final elapsedDays = _elapsedDays(
      window,
      today,
      // „Całość” zaczyna się od początku słupka (np. 1 stycznia) — średnie
      // liczymy od pierwszego treningu, nie od pustych tygodni przed nim.
      firstDay: window.previousStart == null && earliest != null
          ? statsDay(earliest.toLocal())
          : null,
    );
    final progressFrom = _earlier(
      window.start,
      DateTime(today.year, today.month, today.day - progressMinDays),
    );
    final windowExercises = _exercises(
      inWindow,
      completed.where((s) {
        final local = s.startedAt.toLocal();
        return !local.isBefore(progressFrom) && local.isBefore(window.end);
      }),
    );
    final muscles = MuscleDistributionCalculator.compute(inWindow);
    final goal = WeeklyGoalCalculator.compute(
      completed,
      today: today,
      goal: weeklyGoal,
    );
    final daysSinceLast = _daysSinceLast(completed, today);

    return TrainingStatsSnapshot(
      range: range,
      customRange: range == StatsRange.custom ? customRange : null,
      window: window,
      current: current,
      previous: window.previousStart == null
          ? null
          : TrainingSummaryCalculator.aggregate(inPrevious),
      trainingDays: {
        for (final s in inWindow) statsDay(s.startedAt.toLocal()),
      }.length,
      recordsCount: windowRecords.length,
      previousRecordsCount: window.previousStart == null
          ? null
          : previousRecords,
      currentStreakWeeks: streaks.current,
      bestStreakWeeks: streaks.best,
      series: _series(inWindow, window),
      activity: _activity(completed, today, elapsedDays),
      habits: _habits(inWindow, elapsedDays),
      muscles: muscles,
      records: windowRecords,
      bests: allRecords.bests,
      exercises: windowExercises,
      progressFrom: progressFrom,
      hasHistory: completed.isNotEmpty,
      goal: goal,
      repRanges: RepRangeCalculator.compute(inWindow),
      sessionRecords: SessionRecordsCalculator.compute(completed),
      recovery: MuscleRecoveryCalculator.compute(
        all: completed,
        inWindow: inWindow,
        windowWeeks: elapsedDays / 7,
        today: today,
      ),
      daysSinceLastWorkout: daysSinceLast,
      insights: StatsInsightsCalculator.compute(
        current: current,
        previous: window.previousStart == null
            ? null
            : TrainingSummaryCalculator.aggregate(inPrevious),
        windowRecords: windowRecords,
        streakWeeks: streaks.current,
        goal: goal,
        exercises: windowExercises,
        neglectedLabels: [for (final m in muscles.neglected) m.label],
        daysSinceLastWorkout: daysSinceLast,
        today: today,
      ),
    );
  }

  /// Pełne dni od ostatniego treningu; `null` bez historii.
  static int? _daysSinceLast(List<TrainingSession> completed, DateTime today) {
    DateTime? last;
    for (final s in completed) {
      final day = statsDay(s.startedAt.toLocal());
      if (last == null || day.isAfter(last)) last = day;
    }
    if (last == null) return null;
    return DateTime.utc(today.year, today.month, today.day)
        .difference(DateTime.utc(last.year, last.month, last.day))
        .inDays
        .clamp(0, 100000);
  }

  static DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  /// Dni okna, które już minęły (z dzisiejszym) — okno roku kończy się
  /// z końcem miesiąca, a średnie mają dzielić przez czas, który upłynął.
  static int _elapsedDays(
    StatsWindow window,
    DateTime today, {
    DateTime? firstDay,
  }) {
    final from = firstDay != null && firstDay.isAfter(window.start)
        ? firstDay
        : window.start;
    final start = DateTime.utc(from.year, from.month, from.day);
    final end = DateTime.utc(today.year, today.month, today.day + 1);
    final windowEnd = DateTime.utc(
      window.end.year,
      window.end.month,
      window.end.day,
    );
    final last = end.isBefore(windowEnd) ? end : windowEnd;
    return math.max(1, last.difference(start).inDays);
  }

  static List<StatsSeriesPoint> _series(
    List<TrainingSession> sessions,
    StatsWindow window,
  ) {
    final starts = <DateTime>[];
    // Własny zakres nie musi zaczynać się na granicy słupka (poniedziałek,
    // pierwszy dzień miesiąca) — pierwszy słupek jest wtedy niepełny.
    for (
      var cursor = bucketStartOf(window.start, window.bucket);
      cursor.isBefore(window.end);
      cursor = nextBucket(cursor, window.bucket)
    ) {
      starts.add(cursor);
    }

    final byStart = {for (final start in starts) start: _SeriesAccumulator()};
    for (final session in sessions) {
      final key = bucketStartOf(session.startedAt.toLocal(), window.bucket);
      final acc = byStart[key];
      if (acc == null) continue;
      acc.add(session);
    }

    return [
      for (final start in starts)
        byStart[start]!.toPoint(start, nextBucket(start, window.bucket)),
    ];
  }

  static StatsActivity _activity(
    List<TrainingSession> sessions,
    DateTime today,
    int elapsedDays,
  ) {
    final weeks = ((elapsedDays + 6) ~/ 7).clamp(
      activityMinWeeks,
      activityMaxWeeks,
    );
    final thisWeek = TrainingSummaryCalculator.startOfWeek(today);
    final start = DateTime(
      thisWeek.year,
      thisWeek.month,
      thisWeek.day - 7 * (weeks - 1),
    );

    final days = <DateTime, _DayAccumulator>{};
    for (final session in sessions) {
      final day = statsDay(session.startedAt.toLocal());
      if (day.isBefore(start) || day.isAfter(today)) continue;
      (days[day] ??= _DayAccumulator()).add(session);
    }

    return StatsActivity(
      start: start,
      weeks: weeks,
      today: today,
      days: {
        for (final entry in days.entries)
          entry.key: entry.value.toDay(entry.key),
      },
    );
  }

  static TrainingHabits _habits(
    List<TrainingSession> sessions,
    int elapsedDays,
  ) {
    if (sessions.isEmpty) return TrainingHabits.empty;

    final weekdays = List<int>.filled(7, 0);
    final timeOfDay = <TrainingTimeOfDay, int>{};
    var durationSum = 0;
    var durationCount = 0;
    var sets = 0;
    var repsSum = 0;
    var repsSets = 0;
    var rirSum = 0;
    var rirSets = 0;

    for (final session in sessions) {
      final local = session.startedAt.toLocal();
      weekdays[local.weekday - 1]++;
      timeOfDay.update(
        TrainingTimeOfDay.of(local),
        (v) => v + 1,
        ifAbsent: () => 1,
      );
      final seconds = TrainingSummaryCalculator.sessionDurationSec(session);
      if (seconds > 0) {
        durationSum += seconds;
        durationCount++;
      }
      for (final exercise in session.exercises) {
        for (final set in completedSetsOf(exercise)) {
          sets++;
          if (set.reps != null) {
            repsSum += set.reps!;
            repsSets++;
          }
          if (set.rir != null) {
            rirSum += set.rir!;
            rirSets++;
          }
        }
      }
    }

    return TrainingHabits(
      weekdayCounts: List.unmodifiable(weekdays),
      timeOfDayCounts: Map.unmodifiable(timeOfDay),
      avgDurationSec: durationCount == 0 ? null : durationSum ~/ durationCount,
      avgSetsPerWorkout: sets / sessions.length,
      avgRepsPerSet: repsSets == 0 ? null : repsSum / repsSets,
      avgRir: rirSets == 0 ? null : rirSum / rirSets,
      workoutsPerWeek: sessions.length / (elapsedDays / 7),
    );
  }

  /// Seria tygodni z co najmniej jednym treningiem: bieżąca (liczona od tego
  /// tygodnia albo od poprzedniego, gdy w tym jeszcze nie było treningu)
  /// i najdłuższa w historii.
  static ({int current, int best}) _streaks(
    List<TrainingSession> sessions,
    DateTime today,
  ) {
    final weeks = {
      for (final s in sessions)
        TrainingSummaryCalculator.startOfWeek(s.startedAt.toLocal()),
    };
    if (weeks.isEmpty) return (current: 0, best: 0);

    DateTime previousWeek(DateTime w) => DateTime(w.year, w.month, w.day - 7);

    var current = 0;
    var cursor = TrainingSummaryCalculator.startOfWeek(today);
    if (!weeks.contains(cursor)) cursor = previousWeek(cursor);
    while (weeks.contains(cursor)) {
      current++;
      cursor = previousWeek(cursor);
    }

    var best = 0;
    for (final week in weeks) {
      // Liczymy tylko od początku serii — tydzień bez poprzednika.
      if (weeks.contains(previousWeek(week))) continue;
      var length = 0;
      var w = week;
      while (weeks.contains(w)) {
        length++;
        w = DateTime(w.year, w.month, w.day + 7);
      }
      if (length > best) best = length;
    }

    return (current: current, best: best);
  }

  static List<ExerciseProgress> _exercises(
    List<TrainingSession> inWindow,
    Iterable<TrainingSession> progressSessions,
  ) {
    final totals = <String, _ExerciseAccumulator>{};
    for (final session in inWindow) {
      final seen = <String>{};
      for (final exercise in session.exercises) {
        var sets = 0;
        var volume = 0.0;
        for (final set in completedSetsOf(exercise)) {
          sets++;
          volume += set.volumeKg;
        }
        if (sets == 0) continue;
        final key = statsExerciseKey(exercise);
        final acc = totals[key] ??= _ExerciseAccumulator();
        acc
          ..name = exercise.exerciseName.trim()
          ..exerciseId = exercise.exerciseId
          ..sets += sets
          ..volumeKg += volume;
        if (seen.add(key)) acc.sessions++;
      }
    }
    if (totals.isEmpty) return const [];

    final top = totals.entries.toList()
      ..sort((a, b) {
        final bySessions = b.value.sessions.compareTo(a.value.sessions);
        if (bySessions != 0) return bySessions;
        return b.value.sets.compareTo(a.value.sets);
      });
    final chosen = top.take(topExercisesLimit).toList();
    final chosenKeys = {for (final e in chosen) e.key};

    final ordered = progressSessions.toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final points = <String, List<ExerciseProgressPoint>>{};
    for (final session in ordered) {
      final perKey = <String, _PointAccumulator>{};
      for (final exercise in session.exercises) {
        final key = statsExerciseKey(exercise);
        if (!chosenKeys.contains(key)) continue;
        for (final set in completedSetsOf(exercise)) {
          (perKey[key] ??= _PointAccumulator()).add(set);
        }
      }
      for (final entry in perKey.entries) {
        (points[entry.key] ??= []).add(entry.value.toPoint(session.startedAt));
      }
    }

    return [
      for (final entry in chosen)
        ExerciseProgress(
          exerciseKey: entry.key,
          exerciseName: entry.value.name,
          exerciseId: entry.value.exerciseId,
          sessions: entry.value.sessions,
          sets: entry.value.sets,
          volumeKg: entry.value.volumeKg,
          points: List.unmodifiable(points[entry.key] ?? const []),
        ),
    ];
  }
}

class _SeriesAccumulator {
  int workouts = 0;
  int durationSec = 0;
  int sets = 0;
  double volumeKg = 0;

  void add(TrainingSession session) {
    workouts++;
    durationSec += TrainingSummaryCalculator.sessionDurationSec(session);
    for (final exercise in session.exercises) {
      for (final set in completedSetsOf(exercise)) {
        sets++;
        volumeKg += set.volumeKg;
      }
    }
  }

  StatsSeriesPoint toPoint(DateTime start, DateTime end) => StatsSeriesPoint(
    start: start,
    end: end,
    workouts: workouts,
    durationSec: durationSec,
    sets: sets,
    volumeKg: volumeKg,
  );
}

class _DayAccumulator {
  int workouts = 0;
  int sets = 0;
  double volumeKg = 0;
  final sessions = <ActivitySession>[];

  void add(TrainingSession session) {
    workouts++;
    sessions.add(
      ActivitySession(
        id: session.id,
        name: session.planName,
        startedAt: session.startedAt,
      ),
    );
    for (final exercise in session.exercises) {
      for (final set in completedSetsOf(exercise)) {
        sets++;
        volumeKg += set.volumeKg;
      }
    }
  }

  ActivityDay toDay(DateTime day) => ActivityDay(
    day: day,
    workouts: workouts,
    sets: sets,
    volumeKg: volumeKg,
    sessions: List.unmodifiable(
      sessions..sort((a, b) => a.startedAt.compareTo(b.startedAt)),
    ),
  );
}

class _ExerciseAccumulator {
  String name = '';
  String exerciseId = '';
  int sessions = 0;
  int sets = 0;
  double volumeKg = 0;
}

class _PointAccumulator {
  int sets = 0;
  double volumeKg = 0;
  double? topWeightKg;
  double? oneRepMaxKg;
  int? maxReps;

  void add(CompletedSetValues set) {
    sets++;
    volumeKg += set.volumeKg;
    final reps = set.reps;
    if (reps != null && reps > (maxReps ?? 0)) maxReps = reps;
    if (!set.hasWeight) return;
    final weight = set.weightKg!;
    if (weight > (topWeightKg ?? 0)) topWeightKg = weight;
    if (reps != null) {
      final oneRm = ExerciseStats.estimateOneRepMax(weight, reps);
      if (oneRm > (oneRepMaxKg ?? 0)) oneRepMaxKg = oneRm;
    }
  }

  ExerciseProgressPoint toPoint(DateTime date) => ExerciseProgressPoint(
    date: date,
    sets: sets,
    volumeKg: volumeKg,
    topWeightKg: topWeightKg,
    oneRepMaxKg: oneRepMaxKg,
    maxReps: maxReps,
  );
}
