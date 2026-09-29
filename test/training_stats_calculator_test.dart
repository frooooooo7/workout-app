import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';
import 'package:gym/features/training/domain/services/stats/muscle_distribution_calculator.dart';
import 'package:gym/features/training/domain/services/stats/personal_records_calculator.dart';
import 'package:gym/features/training/domain/services/stats/training_stats_calculator.dart';

TrainingSessionSet _set({
  String? weight,
  String? reps,
  String? rir,
  bool completed = true,
}) => TrainingSessionSet(
  actualWeight: weight,
  actualReps: reps,
  actualRir: rir,
  completed: completed,
);

TrainingSessionExercise _exercise(
  String name,
  List<TrainingSessionSet> sets, {
  List<String> muscles = const ['chest'],
  String id = '',
}) => TrainingSessionExercise(
  exerciseId: id,
  exerciseName: name,
  exerciseMuscles: muscles,
  exerciseCategory: 'compound',
  sets: sets,
);

TrainingSession _session(
  DateTime startLocal, {
  Duration duration = const Duration(hours: 1),
  List<TrainingSessionExercise>? exercises,
  TrainingSessionStatus status = TrainingSessionStatus.completed,
}) => TrainingSession(
  planName: 'Push',
  status: status,
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
  group('windowFor', () {
    test('7 and 30 days end today and compare with the same length before', () {
      final week = TrainingStatsCalculator.windowFor(StatsRange.week, _now);
      expect(week.start, DateTime(2026, 9, 10));
      expect(week.end, DateTime(2026, 9, 17));
      expect(week.previousStart, DateTime(2026, 9, 3));
      expect(week.bucket, StatsBucket.day);
      expect(week.days, 7);

      final month = TrainingStatsCalculator.windowFor(StatsRange.month, _now);
      expect(month.start, DateTime(2026, 8, 18));
      expect(month.days, 30);
      expect(month.previousStart, DateTime(2026, 7, 19));
    });

    test('3 months are 13 whole weeks; a year is 12 whole months', () {
      final quarter = TrainingStatsCalculator.windowFor(
        StatsRange.quarter,
        _now,
      );
      expect(quarter.start, DateTime(2026, 6, 22));
      expect(quarter.end, DateTime(2026, 9, 21));
      expect(quarter.bucket, StatsBucket.week);
      expect(quarter.days, 91);

      final year = TrainingStatsCalculator.windowFor(StatsRange.year, _now);
      expect(year.start, DateTime(2025, 10));
      expect(year.end, DateTime(2026, 10));
      expect(year.previousStart, DateTime(2024, 10));
      expect(year.bucket, StatsBucket.month);
    });

    test(
      '"all" picks the bucket from the history span, without comparison',
      () {
        StatsWindow all(DateTime earliest) => TrainingStatsCalculator.windowFor(
          StatsRange.all,
          _now,
          earliest: earliest,
        );

        expect(all(DateTime(2026, 9, 15)).start, DateTime(2026, 9, 10));
        expect(all(DateTime(2026, 9, 1)).bucket, StatsBucket.day);
        expect(all(DateTime(2026, 5, 1)).bucket, StatsBucket.week);
        expect(all(DateTime(2026, 5, 1)).start, DateTime(2026, 4, 27));
        expect(all(DateTime(2024, 3, 9)).bucket, StatsBucket.month);
        expect(all(DateTime(2024, 3, 9)).start, DateTime(2024, 3));
        expect(all(DateTime(2020, 3, 9)).bucket, StatsBucket.year);
        expect(all(DateTime(2020, 3, 9)).previousStart, isNull);
      },
    );
  });

  test('trailingAverage waits for a full window', () {
    expect(TrainingStatsCalculator.trailingAverage([2, 4, 6, 8], 3), [
      null,
      null,
      4,
      6,
    ]);
  });

  group('compute', () {
    test('KPIs compare with the previous period and skip odd sessions', () {
      final snapshot = TrainingStatsCalculator.compute(
        [
          _session(DateTime(2026, 9, 16, 8)),
          _session(DateTime(2026, 9, 16, 10)),
          _session(DateTime(2026, 9, 12, 18)),
          _session(DateTime(2026, 9, 5, 18)), // poprzednie 7 dni
          _session(DateTime(2026, 9, 1, 18)), // poza oboma oknami
          _session(DateTime(2026, 9, 17, 8)), // przyszłość (zły zegar)
          _session(
            DateTime(2026, 9, 14, 18),
            status: TrainingSessionStatus.cancelled,
          ),
        ],
        range: StatsRange.week,
        now: _now,
      );

      expect(snapshot.current.workouts, 3);
      expect(snapshot.current.volumeKg, 3 * 800);
      expect(snapshot.previous!.workouts, 1);
      expect(snapshot.trainingDays, 2);
      expect(snapshot.hasHistory, isTrue);
      expect(snapshot.isEmpty, isFalse);
    });

    test('series has one bucket per day with sums', () {
      final snapshot = TrainingStatsCalculator.compute(
        [
          _session(
            DateTime(2026, 9, 16, 8),
            duration: const Duration(minutes: 30),
          ),
          _session(
            DateTime(2026, 9, 16, 10),
            duration: const Duration(minutes: 45),
          ),
          _session(DateTime(2026, 9, 10, 7)),
        ],
        range: StatsRange.week,
        now: _now,
      );

      expect(snapshot.series, hasLength(7));
      expect(snapshot.series.first.start, DateTime(2026, 9, 10));
      expect(snapshot.series.first.workouts, 1);
      expect(snapshot.series.last.workouts, 2);
      expect(snapshot.series.last.durationSec, 75 * 60);
      expect(snapshot.series.last.volumeKg, 1600);
      expect(snapshot.series[3].workouts, 0);
    });

    test('streaks: current counts from last week when this one is empty', () {
      final snapshot = TrainingStatsCalculator.compute(
        [
          // Seria 3 tygodni zakończona w poprzednim tygodniu.
          _session(DateTime(2026, 9, 9)),
          _session(DateTime(2026, 9, 2)),
          _session(DateTime(2026, 8, 26)),
          // Dawniejsza, dłuższa seria 4 tygodni.
          _session(DateTime(2026, 6, 1)),
          _session(DateTime(2026, 6, 8)),
          _session(DateTime(2026, 6, 15)),
          _session(DateTime(2026, 6, 22)),
        ],
        range: StatsRange.month,
        now: DateTime(2026, 9, 14, 8), // poniedziałek, jeszcze bez treningu
      );

      expect(snapshot.currentStreakWeeks, 3);
      expect(snapshot.bestStreakWeeks, 4);
    });

    test('activity covers at least 12 whole weeks ending this week', () {
      final snapshot = TrainingStatsCalculator.compute(
        [
          _session(DateTime(2026, 9, 16, 8)),
          _session(DateTime(2026, 9, 16, 10)),
          _session(DateTime(2026, 6, 22, 18)), // pierwszy dzień heatmapy
          _session(DateTime(2026, 6, 21, 18)), // przed heatmapą
        ],
        range: StatsRange.week,
        now: _now,
      );

      final activity = snapshot.activity;
      expect(activity.weeks, 12);
      expect(activity.start, DateTime(2026, 6, 29));
      expect(activity.dayAt(DateTime(2026, 9, 16))!.workouts, 2);
      // Sesje dnia od najwcześniejszej — do otwarcia ze szczegółami.
      final sessions = activity.dayAt(DateTime(2026, 9, 16))!.sessions;
      expect(sessions.map((s) => s.name), ['Push', 'Push']);
      expect(
        sessions.first.startedAt.isBefore(sessions.last.startedAt),
        isTrue,
      );
      expect(activity.trainingDays, 1);
    });

    test('habits: weekday, time of day, averages', () {
      final snapshot = TrainingStatsCalculator.compute(
        [
          _session(
            DateTime(2026, 9, 14, 7),
            duration: const Duration(minutes: 40),
            exercises: [
              _exercise('A', [
                _set(weight: '50', reps: '10', rir: '2'),
                _set(weight: '50', reps: '8', rir: '1'),
              ]),
            ],
          ),
          _session(
            DateTime(2026, 9, 15, 7),
            duration: const Duration(minutes: 60),
            exercises: [
              _exercise('A', [_set(reps: '12')]),
            ],
          ),
          _session(
            DateTime(2026, 9, 12, 18),
            duration: const Duration(minutes: 50),
          ),
        ],
        range: StatsRange.week,
        now: _now,
      );

      final habits = snapshot.habits;
      expect(habits.weekdayCounts, [1, 1, 0, 0, 0, 1, 0]);
      expect(habits.timeOfDayCounts[TrainingTimeOfDay.morning], 2);
      expect(habits.favoriteTimeOfDay, TrainingTimeOfDay.morning);
      expect(habits.avgDurationSec, 50 * 60);
      expect(habits.avgSetsPerWorkout, closeTo(4 / 3, 1e-9));
      expect(habits.avgRepsPerSet, closeTo((10 + 8 + 12 + 10) / 4, 1e-9));
      expect(habits.avgRir, closeTo(1.5, 1e-9));
      expect(habits.workoutsPerWeek, closeTo(3, 1e-9));
    });

    test('top exercises are ranked by sessions and carry progress points', () {
      final snapshot = TrainingStatsCalculator.compute(
        [
          _session(
            DateTime(2026, 7, 1, 18), // poza tygodniem, ale w progresie
            exercises: [
              _exercise('Przysiad', [_set(weight: '100', reps: '5')]),
            ],
          ),
          _session(
            DateTime(2026, 9, 14, 18),
            exercises: [
              _exercise('Przysiad', [_set(weight: '110', reps: '5')]),
              _exercise('Wyciskanie', [_set(weight: '80', reps: '5')]),
            ],
          ),
          _session(
            DateTime(2026, 9, 16, 8),
            exercises: [
              _exercise(' przysiad ', [
                _set(weight: '115', reps: '3'),
                _set(weight: '100', reps: '8'),
              ]),
            ],
          ),
        ],
        range: StatsRange.week,
        now: _now,
      );

      expect(snapshot.exercises.map((e) => e.exerciseName), [
        'przysiad',
        'Wyciskanie',
      ]);
      final squat = snapshot.exercises.first;
      expect(squat.sessions, 2);
      expect(squat.sets, 3);
      expect(squat.points, hasLength(3));
      expect(squat.points.last.topWeightKg, 115);
      expect(squat.points.last.oneRepMaxKg, closeTo(100 * (1 + 8 / 30), 1e-9));
      expect(
        squat.change,
        closeTo(100 * (1 + 8 / 30) - 100 * (1 + 5 / 30), 1e-9),
      );
      expect(snapshot.progressFrom, DateTime(2026, 6, 18));
    });

    test('"all" averages start at the first workout, not the bucket', () {
      final snapshot = TrainingStatsCalculator.compute(
        [
          _session(DateTime(2020, 12, 20, 18)),
          _session(DateTime(2026, 9, 14, 8)),
        ],
        range: StatsRange.all,
        now: _now,
      );
      expect(snapshot.window.start, DateTime(2020));
      final days = DateTime.utc(
        2026,
        9,
        17,
      ).difference(DateTime.utc(2020, 12, 20)).inDays;
      expect(snapshot.habits.workoutsPerWeek, closeTo(2 / (days / 7), 1e-9));
    });

    test('empty history', () {
      final snapshot = TrainingStatsCalculator.compute(
        const [],
        range: StatsRange.all,
        now: _now,
      );
      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.hasHistory, isFalse);
      expect(snapshot.series, hasLength(7));
      expect(snapshot.muscles.isEmpty, isTrue);
      expect(snapshot.records, isEmpty);
    });
  });

  group('PersonalRecordsCalculator', () {
    test('first session sets the baseline; later ones beat it', () {
      final result = PersonalRecordsCalculator.compute([
        _session(
          DateTime(2026, 9, 1),
          exercises: [
            _exercise('Wyciskanie', [_set(weight: '80', reps: '5')]),
            _exercise('Podciąganie', [_set(reps: '8')], muscles: ['lats']),
          ],
        ),
        _session(
          DateTime(2026, 9, 8),
          exercises: [
            // Ten sam ciężar, więcej powtórzeń: tylko 1RM.
            _exercise('Wyciskanie', [_set(weight: '80', reps: '8')]),
            _exercise('Podciąganie', [_set(reps: '10')], muscles: ['lats']),
          ],
        ),
        _session(
          DateTime(2026, 9, 15),
          exercises: [
            _exercise('Wyciskanie', [
              _set(weight: '85', reps: '3'),
              _set(weight: '100', reps: '1', completed: false),
            ]),
            _exercise('Podciąganie', [_set(reps: '9')], muscles: ['lats']),
          ],
        ),
      ]);

      expect(result.records, hasLength(3));
      final oneRm = result.records[0];
      expect(oneRm.exerciseName, 'Wyciskanie');
      expect(oneRm.kinds, {PersonalRecordKind.oneRepMax});
      expect(oneRm.weightKg, 80);
      expect(oneRm.reps, 8);
      expect(
        oneRm.improvement,
        closeTo(80 * (1 + 8 / 30) - 80 * (1 + 5 / 30), 1e-9),
      );

      final reps = result.records[1];
      expect(reps.exerciseName, 'Podciąganie');
      expect(reps.primaryKind, PersonalRecordKind.reps);
      expect(reps.reps, 10);
      expect(reps.improvement, 2);

      final weight = result.records[2];
      expect(weight.primaryKind, PersonalRecordKind.weight);
      expect(weight.kinds, {PersonalRecordKind.weight});
      expect(weight.weightKg, 85);
      expect(weight.reps, 3);
      expect(weight.improvement, 5);

      final bench = result.bests.firstWhere(
        (b) => b.exerciseName == 'Wyciskanie',
      );
      expect(bench.bestWeightKg, 85);
      expect(bench.bestOneRepMaxKg, closeTo(80 * (1 + 8 / 30), 1e-9));
      expect(bench.sessions, 3);
      expect(bench.lastImprovedAt, DateTime(2026, 9, 15).toUtc());
    });

    test('an equal result is not a record', () {
      final result = PersonalRecordsCalculator.compute([
        _session(DateTime(2026, 9, 1)),
        _session(DateTime(2026, 9, 8)),
      ]);
      expect(result.records, isEmpty);
      expect(result.bests.single.sessions, 2);
    });

    test('compute() counts only records inside the window', () {
      final snapshot = TrainingStatsCalculator.compute(
        [
          _session(
            DateTime(2026, 8, 1),
            exercises: [
              _exercise('Wyciskanie', [_set(weight: '80', reps: '5')]),
            ],
          ),
          _session(
            DateTime(2026, 9, 5),
            exercises: [
              _exercise('Wyciskanie', [_set(weight: '82,5', reps: '5')]),
            ],
          ),
          _session(
            DateTime(2026, 9, 15),
            exercises: [
              _exercise('Wyciskanie', [_set(weight: '85', reps: '5')]),
            ],
          ),
        ],
        range: StatsRange.week,
        now: _now,
      );
      expect(snapshot.recordsCount, 1);
      expect(snapshot.previousRecordsCount, 1);
      expect(snapshot.records.single.weightKg, 85);
    });
  });

  group('MuscleDistributionCalculator', () {
    test('primary muscle gets whole sets, secondary half; regions once', () {
      final result = MuscleDistributionCalculator.compute([
        _session(
          DateTime(2026, 9, 14),
          exercises: [
            _exercise(
              'Wyciskanie',
              [_set(weight: '80', reps: '10'), _set(weight: '80', reps: '10')],
              muscles: ['chest', 'triceps', 'frontDelts'],
            ),
            _exercise(
              'Wiosłowanie',
              [_set(weight: '60', reps: '10')],
              muscles: ['lats', 'traps'],
            ),
          ],
        ),
      ]);

      MuscleStat stat(MuscleGroup m) =>
          result.muscles.firstWhere((s) => s.muscle == m);
      expect(result.muscles.first.muscle, MuscleGroup.chest);
      expect(stat(MuscleGroup.chest).sets, 2);
      expect(stat(MuscleGroup.chest).intensity, 1);
      expect(stat(MuscleGroup.triceps).sets, 1);
      expect(stat(MuscleGroup.chest).volumeKg, 1600);
      expect(stat(MuscleGroup.traps).sets, 0.5);

      RegionStat region(MuscleRegion r) =>
          result.regions.firstWhere((s) => s.region == r);
      expect(region(MuscleRegion.chest).sets, 2);
      // Najszersze (1.0) i kaptury (0.5) to jedna seria na plecy.
      expect(region(MuscleRegion.back).sets, 1);
      expect(
        result.regions.fold<double>(0, (a, r) => a + r.share),
        closeTo(1, 1e-9),
      );
      // Mniej niż 3 treningi — bez ostrzeżeń.
      expect(result.neglected, isEmpty);
    });

    test('coarse groups stay coarse in the ranking, expand on the body map', () {
      final sessions = [
        for (var i = 0; i < 3; i++)
          _session(
            DateTime(2026, 9, 10 + i),
            exercises: [
              _exercise(
                'Przysiad',
                [_set(weight: '100', reps: '5')],
                muscles: ['legs'],
              ),
            ],
          ),
      ];
      final result = MuscleDistributionCalculator.compute(sessions);

      // Nie zgadujemy, który mięsień nóg pracował.
      expect(result.muscles.map((m) => m.muscle), [MuscleGroup.legs]);
      expect(result.muscles.single.sets, 3);
      expect(result.bodyMap.keys.toSet(), MuscleGroup.legs.expanded);
      expect(result.bodyMap.values, everyElement(1));

      expect(result.neglected, contains(MuscleGroup.chest));
      // Grupa zbiorcza „pokrywa” swoje mięśnie — nie da się stwierdzić braku.
      expect(result.neglected, isNot(contains(MuscleGroup.quads)));
      expect(result.neglected, isNot(contains(MuscleGroup.calves)));
      // Pośladki to osobna grupa.
      expect(result.neglected, contains(MuscleGroup.glutes));
    });

    test('untagged exercises give no distribution and no warnings', () {
      final result = MuscleDistributionCalculator.compute([
        for (var i = 0; i < 4; i++)
          _session(
            DateTime(2026, 9, 10 + i),
            exercises: [
              _exercise('Coś', [_set(reps: '5')], muscles: const []),
            ],
          ),
      ]);
      expect(result.isEmpty, isTrue);
      expect(result.neglected, isEmpty);
    });
  });
}
