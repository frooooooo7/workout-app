import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';
import 'package:gym/features/training/domain/models/training_summary_stats.dart';
import 'package:gym/features/training/domain/services/stats/muscle_recovery_calculator.dart';
import 'package:gym/features/training/domain/services/stats/rep_range_calculator.dart';
import 'package:gym/features/training/domain/services/stats/session_records_calculator.dart';
import 'package:gym/features/training/domain/services/stats/stats_insights_calculator.dart';
import 'package:gym/features/training/domain/services/stats/training_stats_calculator.dart';
import 'package:gym/features/training/domain/services/stats/weekly_goal_calculator.dart';
import 'package:gym/features/training/domain/services/training_summary_calculator.dart';

TrainingSessionSet _set({
  String? weight,
  String? reps,
  DateTime? at,
  bool completed = true,
}) => TrainingSessionSet(
  actualWeight: weight,
  actualReps: reps,
  completed: completed,
  completedAt: at?.toUtc(),
);

TrainingSessionExercise _exercise(
  String name,
  List<TrainingSessionSet> sets, {
  List<String> muscles = const ['chest'],
}) => TrainingSessionExercise(
  exerciseId: '',
  exerciseName: name,
  exerciseMuscles: muscles,
  exerciseCategory: 'compound',
  sets: sets,
);

TrainingSession _session(
  DateTime startLocal, {
  Duration duration = const Duration(hours: 1),
  List<TrainingSessionExercise>? exercises,
  String name = 'Push',
}) => TrainingSession(
  planName: name,
  status: TrainingSessionStatus.completed,
  startedAt: startLocal.toUtc(),
  finishedAt: startLocal.add(duration).toUtc(),
  exercises:
      exercises ??
      [
        _exercise('Wyciskanie', [_set(weight: '80', reps: '10')]),
      ],
);

/// Środa 16 września 2026, 12:00.
final _now = DateTime(2026, 9, 16, 12);

void main() {
  group('session duration', () {
    test('is end minus start for a normal session', () {
      expect(
        TrainingSummaryCalculator.sessionDurationSec(
          _session(
            DateTime(2026, 9, 14, 18),
            duration: const Duration(minutes: 55),
          ),
        ),
        55 * 60,
      );
    });

    test('a forgotten "finish" is cut to the last set plus a margin', () {
      final start = DateTime(2026, 9, 14, 18);
      final session = _session(
        start,
        duration: const Duration(hours: 14),
        exercises: [
          _exercise('A', [
            _set(
              weight: '50',
              reps: '8',
              at: start.add(const Duration(minutes: 20)),
            ),
            _set(
              weight: '50',
              reps: '8',
              at: start.add(const Duration(minutes: 50)),
            ),
          ]),
        ],
      );
      expect(
        TrainingSummaryCalculator.sessionDurationSec(session),
        (50 + 10) * 60,
      );
    });

    test('a duration typed in the editor is not overridden by set times', () {
      final start = DateTime(2026, 9, 14, 18);
      // Ostatnia seria po 50 min, ale ktoś poprawił czas na 90 min.
      final session = _session(
        start,
        duration: const Duration(minutes: 90),
        exercises: [
          _exercise('A', [
            _set(
              weight: '50',
              reps: '8',
              at: start.add(const Duration(minutes: 20)),
            ),
            _set(
              weight: '50',
              reps: '8',
              at: start.add(const Duration(minutes: 50)),
            ),
          ]),
        ],
      );
      expect(TrainingSummaryCalculator.sessionDurationSec(session), 90 * 60);
    });

    test('set times before the start or clumped at the start are ignored', () {
      final start = DateTime(2026, 9, 14, 18);
      TrainingSession withStamps(List<DateTime> at) => _session(
        start,
        duration: const Duration(minutes: 70),
        exercises: [
          _exercise('A', [for (final t in at) _set(reps: '8', at: t)]),
        ],
      );
      expect(
        TrainingSummaryCalculator.sessionDurationSec(
          withStamps([
            start.subtract(const Duration(minutes: 9)),
            start.subtract(const Duration(minutes: 9)),
          ]),
        ),
        70 * 60,
      );
      expect(
        TrainingSummaryCalculator.sessionDurationSec(
          withStamps([
            for (var i = 0; i < 12; i++) start.add(const Duration(minutes: 2)),
          ]),
        ),
        70 * 60,
      );
    });

    test('a single timestamped set is not trusted, the 5 h cap applies', () {
      final start = DateTime(2026, 9, 14, 18);
      final session = _session(
        start,
        duration: const Duration(hours: 14),
        exercises: [
          _exercise('A', [
            _set(
              weight: '50',
              reps: '8',
              at: start.add(const Duration(minutes: 1)),
            ),
          ]),
        ],
      );
      expect(
        TrainingSummaryCalculator.sessionDurationSec(session),
        TrainingSummaryCalculator.maxSessionSec,
      );
    });

    test('feeds the KPI and the habits average', () {
      final start = DateTime(2026, 9, 14, 8);
      final snapshot = TrainingStatsCalculator.compute(
        [_session(start, duration: const Duration(hours: 20))],
        range: StatsRange.week,
        now: _now,
      );
      expect(
        snapshot.current.durationSec,
        TrainingSummaryCalculator.maxSessionSec,
      );
      expect(
        snapshot.habits.avgDurationSec,
        TrainingSummaryCalculator.maxSessionSec,
      );
    });
  });

  group('comparison uses the same elapsed span', () {
    test('quarter: an unfinished week is not compared with a full one', () {
      final window = TrainingStatsCalculator.windowFor(
        StatsRange.quarter,
        _now,
      );
      // Bieżący tydzień to pn–śr (3 dni z 7) — porównujemy 12*7 + 3 dni.
      expect(window.start, DateTime(2026, 6, 22));
      expect(window.previousStart, DateTime(2026, 3, 23));
      expect(window.previousEnd, DateTime(2026, 3, 23 + 12 * 7 + 3));
      expect(window.containsPrevious(DateTime(2026, 6, 20)), isFalse);
    });

    test('year: the running month is compared with the same days only', () {
      final window = TrainingStatsCalculator.windowFor(StatsRange.year, _now);
      expect(window.previousStart, DateTime(2024, 10));
      expect(window.previousEnd!.isBefore(window.start), isTrue);
      // Poprzedni okres nie sięga tak daleko, jak pełny rok.
      expect(window.containsPrevious(DateTime(2025, 9, 30)), isFalse);
    });

    test('7 and 30 days keep the full previous period', () {
      final week = TrainingStatsCalculator.windowFor(StatsRange.week, _now);
      expect(week.previousEnd, isNull);
      expect(week.containsPrevious(DateTime(2026, 9, 9)), isTrue);
    });

    test('delta is not dragged down by the days that have not happened', () {
      // Po jednym treningu w każdym z 13 tygodni poprzedniego kwartału i w
      // każdym tygodniu bieżącego do środy — dokładnie tyle samo.
      final sessions = [
        for (var w = 0; w < 12; w++) _session(DateTime(2026, 6, 22 + 7 * w, 8)),
        _session(DateTime(2026, 9, 14, 8)),
        for (var w = 0; w < 12; w++) _session(DateTime(2026, 3, 23 + 7 * w, 8)),
        _session(DateTime(2026, 6, 15, 8)), // pn tygodnia 13. poprzedniego
        // Sesja z „przyszłej” części poprzedniego okresu nie liczy się.
        _session(DateTime(2026, 6, 19, 8)),
      ];
      final snapshot = TrainingStatsCalculator.compute(
        sessions,
        range: StatsRange.quarter,
        now: _now,
      );
      expect(snapshot.current.workouts, 13);
      expect(snapshot.previous!.workouts, 13);
    });
  });

  group('custom range', () {
    final range = StatsDateRange(DateTime(2026, 9, 2), DateTime(2026, 9, 9));

    test(
      'window is inclusive, compares with the previous span of equal length',
      () {
        final window = TrainingStatsCalculator.windowFor(
          StatsRange.custom,
          _now,
          custom: range,
        );
        expect(range.days, 8);
        expect(window.start, DateTime(2026, 9, 2));
        expect(window.end, DateTime(2026, 9, 10));
        expect(window.previousStart, DateTime(2026, 8, 25));
        expect(window.containsPrevious(DateTime(2026, 9, 1, 23)), isTrue);
        expect(window.containsPrevious(DateTime(2026, 8, 24, 23)), isFalse);
        expect(window.bucket, StatsBucket.day);
      },
    );

    test('an end in the future is clamped to today', () {
      final window = TrainingStatsCalculator.windowFor(
        StatsRange.custom,
        _now,
        custom: StatsDateRange(DateTime(2026, 9, 10), DateTime(2026, 9, 30)),
      );
      expect(window.end, DateTime(2026, 9, 17));
    });

    test('a future end compares with a previous span of the same length', () {
      // Środa: zakres pn–nd ma za sobą 3 dni, więc porównujemy z 3 dniami.
      final window = TrainingStatsCalculator.windowFor(
        StatsRange.custom,
        _now,
        custom: StatsDateRange(DateTime(2026, 9, 14), DateTime(2026, 9, 20)),
      );
      expect(window.end, DateTime(2026, 9, 17));
      expect(window.previousStart, DateTime(2026, 9, 11));
      expect(window.containsPrevious(DateTime(2026, 9, 13, 12)), isTrue);
      expect(window.containsPrevious(DateTime(2026, 9, 10, 12)), isFalse);
    });

    test('a range entirely in the future collapses to today', () {
      final window = TrainingStatsCalculator.windowFor(
        StatsRange.custom,
        _now,
        custom: StatsDateRange(DateTime(2026, 9, 20), DateTime(2026, 9, 25)),
      );
      expect(window.start, DateTime(2026, 9, 16));
      expect(window.end, DateTime(2026, 9, 17));
      expect(window.previousStart, DateTime(2026, 9, 15));
      expect(window.end.isAfter(window.start), isTrue);
    });

    test('workouts per week is never inflated by a window under a week', () {
      final snapshot = TrainingStatsCalculator.compute(
        [_session(DateTime(2026, 9, 15, 8))],
        range: StatsRange.custom,
        customRange: StatsDateRange(
          DateTime(2026, 9, 15),
          DateTime(2026, 9, 15),
        ),
        now: _now,
      );
      expect(snapshot.current.workouts, 1);
      expect(snapshot.habits.workoutsPerWeek, 1);
    });

    test('long spans move to weekly and monthly buckets', () {
      StatsBucket bucket(DateTime a, DateTime b) =>
          TrainingStatsCalculator.windowFor(
            StatsRange.custom,
            _now,
            custom: StatsDateRange(a, b),
          ).bucket;
      expect(
        bucket(DateTime(2026, 8, 1), DateTime(2026, 9, 10)),
        StatsBucket.week,
      );
      expect(
        bucket(DateTime(2025, 1, 1), DateTime(2026, 9, 10)),
        StatsBucket.month,
      );
      expect(
        bucket(DateTime(2020, 1, 1), DateTime(2026, 9, 10)),
        StatsBucket.year,
      );
    });

    test('counts only chosen days but aligns the first weekly bucket', () {
      final chosen = StatsDateRange(DateTime(2026, 7, 8), DateTime(2026, 9, 9));
      final snapshot = TrainingStatsCalculator.compute(
        [
          _session(DateTime(2026, 7, 7, 8)), // dzień przed zakresem
          _session(DateTime(2026, 7, 8, 8)),
          _session(DateTime(2026, 9, 9, 20)), // ostatni dzień zakresu
          _session(DateTime(2026, 9, 10, 8)), // dzień po
        ],
        range: StatsRange.custom,
        customRange: chosen,
        now: _now,
      );

      expect(snapshot.range, StatsRange.custom);
      expect(snapshot.customRange, chosen);
      expect(snapshot.current.workouts, 2);
      expect(snapshot.window.bucket, StatsBucket.week);
      // 8 lipca to środa — pierwszy słupek zaczyna się w poniedziałek 6 lipca
      // i nie gubi sesji.
      expect(snapshot.series.first.start, DateTime(2026, 7, 6));
      expect(snapshot.series.first.workouts, 1);
      expect(snapshot.series.fold<int>(0, (a, p) => a + p.workouts), 2);
    });
  });

  group('WeeklyGoalCalculator', () {
    test('null without a valid goal', () {
      expect(
        WeeklyGoalCalculator.compute(
          const [],
          today: DateTime(2026, 9, 16),
          goal: null,
        ),
        isNull,
      );
      expect(
        WeeklyGoalCalculator.compute(
          const [],
          today: DateTime(2026, 9, 16),
          goal: 0,
        ),
        isNull,
      );
      expect(
        WeeklyGoalCalculator.compute(
          const [],
          today: DateTime(2026, 9, 16),
          goal: 30,
        ),
        isNull,
      );
    });

    test('progress, remaining days and weekly history', () {
      final goal = WeeklyGoalCalculator.compute(
        [
          _session(DateTime(2026, 9, 14, 8)),
          _session(DateTime(2026, 9, 15, 8)),
          _session(DateTime(2026, 9, 8, 8)),
        ],
        today: DateTime(2026, 9, 16),
        goal: 3,
      )!;

      expect(goal.workoutsThisWeek, 2);
      expect(goal.met, isFalse);
      expect(goal.remaining, 1);
      expect(goal.daysLeft, 4); // czwartek–niedziela
      expect(goal.reachable, isTrue);
      expect(goal.weeks, hasLength(WeeklyGoalCalculator.weeksShown));
      expect(goal.weeks.last.start, DateTime(2026, 9, 14));
      expect(goal.weeks.last.workouts, 2);
      expect(goal.weeks[goal.weeks.length - 2].workouts, 1);
    });

    test(
      'streak counts weeks that met the goal; an open week does not break it',
      () {
        final sessions = [
          // Tygodnie z celem 2: 8.09, 1.09, 25.08 (3 z rzędu), potem przerwa,
          // wcześniej dłuższa seria 4 tygodni.
          for (final week in [
            DateTime(2026, 9, 7),
            DateTime(2026, 8, 31),
            DateTime(2026, 8, 24),
            DateTime(2026, 6, 1),
            DateTime(2026, 6, 8),
            DateTime(2026, 6, 15),
            DateTime(2026, 6, 22),
          ]) ...[
            _session(week.add(const Duration(hours: 8))),
            _session(week.add(const Duration(days: 2, hours: 8))),
          ],
          _session(DateTime(2026, 9, 14, 8)), // bieżący tydzień: 1 z 2
        ];
        final goal = WeeklyGoalCalculator.compute(
          sessions,
          today: DateTime(2026, 9, 16),
          goal: 2,
        )!;
        expect(goal.streakWeeks, 3);
        expect(goal.bestStreakWeeks, 4);
      },
    );

    test('a met current week extends the streak', () {
      final goal = WeeklyGoalCalculator.compute(
        [
          _session(DateTime(2026, 9, 14, 8)),
          _session(DateTime(2026, 9, 15, 8)),
          _session(DateTime(2026, 9, 7, 8)),
          _session(DateTime(2026, 9, 8, 8)),
        ],
        today: DateTime(2026, 9, 16),
        goal: 2,
      )!;
      expect(goal.met, isTrue);
      expect(goal.streakWeeks, 2);
    });

    test('flows into the snapshot', () {
      final snapshot = TrainingStatsCalculator.compute(
        [_session(DateTime(2026, 9, 15, 8))],
        range: StatsRange.month,
        now: _now,
        weeklyGoal: 3,
      );
      expect(snapshot.goal!.goal, 3);
      expect(snapshot.goal!.workoutsThisWeek, 1);
      expect(
        TrainingStatsCalculator.compute(
          [_session(DateTime(2026, 9, 15, 8))],
          range: StatsRange.month,
          now: _now,
        ).goal,
        isNull,
      );
    });
  });

  group('RepRangeCalculator', () {
    test('splits completed sets into strength, mass and endurance', () {
      final result = RepRangeCalculator.compute([
        _session(
          DateTime(2026, 9, 14),
          exercises: [
            _exercise('A', [
              _set(reps: '3'),
              _set(reps: '5'),
              _set(reps: '6'),
              _set(reps: '12'),
              _set(reps: '13'),
              _set(reps: '20'),
              _set(reps: '8-10'), // zakres — bez liczby
              _set(reps: '5', completed: false),
              _set(),
            ]),
          ],
        ),
      ]);
      expect(result.strength, 2);
      expect(result.hypertrophy, 2);
      expect(result.endurance, 2);
      expect(result.total, 6);
      expect(result.shareOf(RepRange.strength), closeTo(1 / 3, 1e-9));
      expect(RepRangeDistribution.empty.dominant, isNull);
      expect(
        const RepRangeDistribution(hypertrophy: 4, strength: 1).dominant,
        RepRange.hypertrophy,
      );
    });
  });

  group('SessionRecordsCalculator', () {
    test('finds the heaviest, longest, biggest sessions and the best week', () {
      final result = SessionRecordsCalculator.compute([
        _session(
          DateTime(2026, 9, 1, 18),
          name: 'Ciężka',
          duration: const Duration(minutes: 50),
          exercises: [
            _exercise('A', [
              _set(weight: '100', reps: '10'),
              _set(weight: '100', reps: '10'),
            ]),
          ],
        ),
        _session(
          DateTime(2026, 9, 8, 18),
          name: 'Długa',
          duration: const Duration(minutes: 95),
          exercises: [
            _exercise('A', [
              for (var i = 0; i < 5; i++) _set(weight: '20', reps: '10'),
            ]),
          ],
        ),
        _session(
          DateTime(2026, 9, 9, 18),
          name: 'Kolejna',
          duration: const Duration(minutes: 30),
          exercises: [
            _exercise('A', [_set(weight: '90', reps: '10')]),
          ],
        ),
      ]);

      expect(result.of(SessionRecordKind.volume)!.name, 'Ciężka');
      expect(result.of(SessionRecordKind.volume)!.value, 2000);
      expect(result.of(SessionRecordKind.duration)!.name, 'Długa');
      expect(result.of(SessionRecordKind.duration)!.value, 95 * 60);
      expect(result.of(SessionRecordKind.sets)!.name, 'Długa');
      expect(result.of(SessionRecordKind.sets)!.value, 5);

      // Tydzień od 7 września: 1000 + 900; od 31 sierpnia: 2000.
      expect(result.bestWeek!.start, DateTime(2026, 8, 31));
      expect(result.bestWeek!.volumeKg, 2000);
      expect(result.bestWeek!.workouts, 1);
    });

    test('bodyweight-only history has no volume record', () {
      final result = SessionRecordsCalculator.compute([
        _session(
          DateTime(2026, 9, 1),
          exercises: [
            _exercise('Pompki', [_set(reps: '20')]),
          ],
        ),
      ]);
      expect(result.of(SessionRecordKind.volume), isNull);
      expect(result.bestWeek, isNull);
      expect(result.of(SessionRecordKind.sets)!.value, 1);
      expect(SessionRecordsCalculator.compute(const []).isEmpty, isTrue);
    });

    test('the first session to set a record keeps it on a tie', () {
      final result = SessionRecordsCalculator.compute([
        _session(DateTime(2026, 9, 8), name: 'Później'),
        _session(DateTime(2026, 9, 1), name: 'Wcześniej'),
      ]);
      expect(result.of(SessionRecordKind.volume)!.name, 'Wcześniej');
    });
  });

  group('MuscleRecoveryCalculator', () {
    test('last trained day per muscle and weekly sets in the window', () {
      final sessions = [
        _session(
          DateTime(2026, 9, 1, 18),
          exercises: [
            _exercise(
              'Przysiad',
              [_set(weight: '100', reps: '5')],
              muscles: ['legs'],
            ),
          ],
        ),
        _session(
          DateTime(2026, 9, 14, 18),
          exercises: [
            _exercise(
              'Wyciskanie',
              [_set(weight: '80', reps: '8'), _set(weight: '80', reps: '8')],
              muscles: ['chest', 'triceps'],
            ),
          ],
        ),
      ];
      final result = MuscleRecoveryCalculator.compute(
        all: sessions,
        inWindow: [sessions[1]],
        windowWeeks: 2,
        today: DateTime(2026, 9, 16),
      );

      expect(result.map((r) => r.muscle).toSet(), {
        MuscleGroup.chest,
        MuscleGroup.triceps,
        MuscleGroup.legs,
      });
      final chest = result.firstWhere((r) => r.muscle == MuscleGroup.chest);
      expect(chest.daysSince, 2);
      expect(chest.setsPerWeek, 1); // 2 serie / 2 tygodnie
      final triceps = result.firstWhere((r) => r.muscle == MuscleGroup.triceps);
      expect(triceps.setsPerWeek, 0.5); // wspomagający: po pół
      final legs = result.firstWhere((r) => r.muscle == MuscleGroup.legs);
      expect(legs.daysSince, 15);
      expect(legs.setsPerWeek, 0, reason: 'nie pracował w oknie');
      // Od ostatnio trenowanego.
      expect(result.first.daysSince <= result.last.daysSince, isTrue);
    });

    test('is part of the snapshot and ignores the chosen range for "last"', () {
      final snapshot = TrainingStatsCalculator.compute(
        [
          _session(
            DateTime(2026, 6, 1, 18),
            exercises: [
              _exercise(
                'Przysiad',
                [_set(weight: '100', reps: '5')],
                muscles: ['legs'],
              ),
            ],
          ),
          _session(DateTime(2026, 9, 15, 8)),
        ],
        range: StatsRange.week,
        now: _now,
      );
      final legs = snapshot.recovery.firstWhere(
        (r) => r.muscle == MuscleGroup.legs,
      );
      expect(legs.daysSince, 107);
      expect(snapshot.recovery.first.muscle, MuscleGroup.chest);
    });
  });

  group('StatsInsightsCalculator', () {
    TrainingPeriodStats stats({int workouts = 4, double volume = 1000}) =>
        TrainingPeriodStats(workouts: workouts, volumeKg: volume);

    List<StatsInsight> insights({
      TrainingPeriodStats? current,
      TrainingPeriodStats? previous,
      List<PersonalRecord> records = const [],
      int streak = 0,
      WeeklyGoalProgress? goal,
      List<ExerciseProgress> exercises = const [],
      List<String> neglected = const [],
      int? daysSince,
      DateTime? today,
    }) => StatsInsightsCalculator.compute(
      current: current ?? stats(),
      previous: previous,
      windowRecords: records,
      streakWeeks: streak,
      goal: goal,
      exercises: exercises,
      neglectedLabels: neglected,
      daysSinceLastWorkout: daysSince,
      today: today ?? DateTime(2026, 9, 16),
    );

    test('volume up and down have different thresholds', () {
      expect(
        insights(previous: stats(volume: 800)).single.text,
        'Objętość wzrosła o 25% względem poprzedniego okresu.',
      );
      expect(insights(previous: stats(volume: 950)), isEmpty);
      // −10% to jeszcze normalna zmienność.
      expect(insights(previous: stats(volume: 1110)), isEmpty);
      final down = insights(previous: stats(volume: 1500)).single;
      expect(down.kind, StatsInsightKind.volumeDown);
      expect(down.tone, StatsInsightTone.attention);
      expect(down.text, 'Objętość spadła o 33% względem poprzedniego okresu.');
    });

    test('no volume insight when either period is empty', () {
      expect(insights(previous: stats(workouts: 0, volume: 0)), isEmpty);
      expect(
        insights(current: stats(workouts: 0, volume: 0), previous: stats()),
        isEmpty,
      );
    });

    test('inactivity, records and streak', () {
      expect(
        insights(daysSince: 9).single.text,
        'Ostatni trening był 9 dni temu. Wróć do rytmu.',
      );
      expect(insights(daysSince: 6), isEmpty);
      expect(
        insights(daysSince: 1, streak: 5).single.text,
        'Seria 5 tygodni z rzędu z treningiem.',
      );
      expect(insights(streak: 2), isEmpty);

      PersonalRecord record(String name) => PersonalRecord(
        exerciseKey: name,
        exerciseName: name,
        exerciseId: 'id-$name',
        sessionId: 's',
        date: DateTime(2026, 9, 15),
        kinds: {PersonalRecordKind.weight},
      );
      expect(
        insights(records: [record('Martwy ciąg')]).single.text,
        'Nowy rekord: Martwy ciąg.',
      );
      final many = insights(
        records: [record('A'), record('B'), record('C')],
      ).single;
      expect(many.text, '3 nowe rekordy — ostatni: A.');
      expect(many.exerciseId, 'id-A');
    });

    test('goal: met, and behind only late in the week while reachable', () {
      WeeklyGoalProgress goal(int done, {int target = 4}) => WeeklyGoalProgress(
        goal: target,
        workoutsThisWeek: done,
        weeks: const [],
        streakWeeks: 0,
        bestStreakWeeks: 0,
        daysLeft: 7 - DateTime(2026, 9, 17).weekday,
      );
      expect(
        insights(goal: goal(4), today: DateTime(2026, 9, 17)).single.text,
        'Cel tygodnia wykonany: 4 z 4 treningów.',
      );
      // Czwartek: brakują 2 treningi, zostały 4 dni.
      final behind = insights(
        goal: goal(2),
        today: DateTime(2026, 9, 17),
      ).single;
      expect(behind.kind, StatsInsightKind.goalBehind);
      expect(behind.text, 'Do celu tygodnia brakuje 2 treningów.');
      // Wtorek — za wcześnie na ponaglanie.
      expect(insights(goal: goal(0), today: DateTime(2026, 9, 15)), isEmpty);
    });

    test('plateau: no improvement over the last sessions', () {
      ExerciseProgress exercise(List<double> oneRm) => ExerciseProgress(
        exerciseKey: 'k',
        exerciseName: 'Wyciskanie',
        exerciseId: 'bench',
        sessions: oneRm.length,
        sets: oneRm.length * 3,
        volumeKg: 0,
        points: [
          for (var i = 0; i < oneRm.length; i++)
            ExerciseProgressPoint(
              date: DateTime(2026, 8, 1 + i * 3),
              sets: 3,
              volumeKg: 0,
              oneRepMaxKg: oneRm[i],
            ),
        ],
      );

      final stuck = insights(
        exercises: [
          exercise([90, 95, 100, 100, 99, 100, 100, 99]),
        ],
      );
      expect(stuck.single.kind, StatsInsightKind.plateau);
      expect(stuck.single.text, 'Wyciskanie: bez progresu od 5 treningów.');
      expect(stuck.single.exerciseId, 'bench');

      // Rośnie — jest wniosek o progresie, nie o stagnacji.
      final growing = insights(
        exercises: [
          exercise([90, 92, 94, 96, 98, 100, 102]),
        ],
      );
      expect(growing.single.kind, StatsInsightKind.progress);
      expect(growing.single.text, 'Wyciskanie: szacowane 1RM wzrosło o 12 kg.');

      // Za mało treningów, żeby mówić o plateau.
      expect(
        insights(
          exercises: [
            exercise([100, 100, 100, 100, 100]),
          ],
        ),
        isEmpty,
      );
    });

    test('an exercise with a record in the window is never "stalled"', () {
      // 100×8 sześć razy, potem 105×3: rekord ciężaru, ale niższe 1RM.
      final points = [
        for (var i = 0; i < 6; i++)
          ExerciseProgressPoint(
            date: DateTime(2026, 8, 1 + i * 3),
            sets: 3,
            volumeKg: 0,
            oneRepMaxKg: 100 * (1 + 8 / 30),
          ),
        ExerciseProgressPoint(
          date: DateTime(2026, 8, 25),
          sets: 3,
          volumeKg: 0,
          oneRepMaxKg: 105 * (1 + 3 / 30),
        ),
      ];
      final bench = ExerciseProgress(
        exerciseKey: 'name:wyciskanie',
        exerciseName: 'Wyciskanie',
        exerciseId: 'bench',
        sessions: 7,
        sets: 21,
        volumeKg: 0,
        points: points,
      );
      PersonalRecord record(String key) => PersonalRecord(
        exerciseKey: key,
        exerciseName: 'Wyciskanie',
        exerciseId: 'bench',
        sessionId: 's',
        date: DateTime(2026, 8, 25),
        kinds: {PersonalRecordKind.weight},
      );

      expect(
        insights(exercises: [bench]).map((i) => i.kind),
        contains(StatsInsightKind.plateau),
      );
      final withRecord = insights(
        exercises: [bench],
        records: [record('name:wyciskanie')],
      );
      expect(withRecord.map((i) => i.kind), [StatsInsightKind.records]);
    });

    test('progress below one kilogram is noise, not a headline', () {
      ExerciseProgress exercise(double first, double last) => ExerciseProgress(
        exerciseKey: 'k',
        exerciseName: 'Wyciskanie',
        exerciseId: 'bench',
        sessions: 3,
        sets: 9,
        volumeKg: 0,
        points: [
          for (final (i, v) in [first, (first + last) / 2, last].indexed)
            ExerciseProgressPoint(
              date: DateTime(2026, 9, 1 + i),
              sets: 3,
              volumeKg: 0,
              oneRepMaxKg: v,
            ),
        ],
      );
      expect(insights(exercises: [exercise(100, 100.04)]), isEmpty);
      expect(insights(exercises: [exercise(100, 100.9)]), isEmpty);
      expect(
        insights(exercises: [exercise(100, 101)]).single.text,
        'Wyciskanie: szacowane 1RM wzrosło o 1 kg.',
      );
    });

    test('caps the list, one insight per rule, most urgent first', () {
      final list = insights(
        daysSince: 10,
        streak: 6,
        neglected: ['Łydki', 'Przedramiona'],
        previous: stats(volume: 500),
        records: [
          PersonalRecord(
            exerciseKey: 'k',
            exerciseName: 'X',
            exerciseId: '',
            sessionId: 's',
            date: DateTime(2026, 9, 15),
            kinds: {PersonalRecordKind.weight},
          ),
        ],
      );
      expect(list, hasLength(StatsInsightsCalculator.maxInsights));
      expect(list.first.kind, StatsInsightKind.inactivity);
      expect(list.map((i) => i.kind).toSet(), hasLength(list.length));
      expect(
        list.map((i) => i.kind),
        isNot(contains(StatsInsightKind.neglected)),
        reason: 'najmniej pilny odpada przy limicie',
      );
    });

    test('are part of the snapshot', () {
      final snapshot = TrainingStatsCalculator.compute(
        [
          _session(
            DateTime(2026, 9, 1, 8),
            exercises: [
              _exercise('Wyciskanie', [_set(weight: '80', reps: '5')]),
            ],
          ),
          _session(
            DateTime(2026, 9, 15, 8),
            exercises: [
              _exercise('Wyciskanie', [_set(weight: '90', reps: '5')]),
            ],
          ),
        ],
        range: StatsRange.month,
        now: _now,
      );
      expect(snapshot.daysSinceLastWorkout, 1);
      expect(
        snapshot.insights.map((i) => i.kind),
        contains(StatsInsightKind.records),
      );
    });
  });
}
