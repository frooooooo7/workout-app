import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/services/workout_comparison.dart';

TrainingSessionSet _set(
  String weight,
  String reps, {
  bool completed = true,
  SetType type = SetType.normal,
}) => TrainingSessionSet(
  setType: type,
  actualWeight: weight,
  actualReps: reps,
  completed: completed,
);

TrainingSessionExercise _exercise(
  String name,
  List<TrainingSessionSet> sets, {
  ExerciseTracking tracking = ExerciseTracking.weightReps,
}) => TrainingSessionExercise(
  exerciseId: name.toLowerCase(),
  exerciseName: name,
  exerciseMuscles: const ['chest'],
  exerciseCategory: 'compound',
  sets: sets,
  tracking: tracking,
);

TrainingSession _session(
  DateTime startedAt,
  List<TrainingSessionExercise> exercises, {
  String id = '',
  String planName = 'Push A',
  String? planLocalId = 'plan-1',
  String? planServerId,
  int minutes = 60,
}) => TrainingSession(
  id: id.isEmpty ? startedAt.toIso8601String() : id,
  planName: planName,
  planLocalId: planLocalId,
  planServerId: planServerId,
  status: TrainingSessionStatus.completed,
  startedAt: startedAt,
  finishedAt: startedAt.add(Duration(minutes: minutes)),
  exercises: exercises,
);

TrainingSession _free(DateTime startedAt, List<TrainingSessionExercise> e) =>
    _session(
      startedAt,
      e,
      planName: TrainingSession.defaultCustomName,
      planLocalId: null,
    );

final _monday = DateTime.utc(2026, 11, 2, 17);
final _thursday = DateTime.utc(2026, 11, 5, 17);

void main() {
  group('plan matching', () {
    test('compares with the previous completed session of the same plan', () {
      final older = _session(DateTime.utc(2026, 10, 26, 17), [
        _exercise('Bench', [_set('60', '8')]),
      ]);
      final previous = _session(_monday, [
        _exercise('Bench', [_set('80', '8'), _set('80', '8')]),
      ]);
      final other = _session(
        DateTime.utc(2026, 11, 3, 17),
        [
          _exercise('Bench', [_set('100', '5')]),
        ],
        planLocalId: 'plan-2',
        planName: 'Pull',
      );
      final today = _session(_thursday, [
        _exercise('Bench', [_set('82,5', '8'), _set('82,5', '8')]),
      ]);

      final result = compareWithPrevious(today, [
        older,
        previous,
        other,
        today,
      ]);

      expect(result!.kind, WorkoutComparisonKind.plan);
      expect(result.previousSessionId, previous.id);
      expect(result.previousDate, _monday);
      // 2 × 80 × 8 = 1280 → 2 × 82,5 × 8 = 1320.
      expect(result.totals!.previousVolumeKg, 1280);
      expect(result.totals!.volumeKg, 1320);
      expect(result.totals!.volumeDeltaKg, 40);
      expect(result.totals!.setsDelta, 0);
    });

    test('matches by server plan id when local ids differ', () {
      final previous = _session(
        _monday,
        [
          _exercise('Bench', [_set('80', '8')]),
        ],
        planLocalId: null,
        planServerId: 'srv-1',
      );
      final today = _session(
        _thursday,
        [
          _exercise('Bench', [_set('82,5', '8')]),
        ],
        planLocalId: 'plan-1',
        planServerId: 'srv-1',
      );

      expect(
        compareWithPrevious(today, [previous])!.previousSessionId,
        previous.id,
      );
    });

    test('falls back to the plan name when only one kind of id is shared', () {
      final previous = _session(
        _monday,
        [
          _exercise('Bench', [_set('80', '8')]),
        ],
        planLocalId: null,
        planServerId: 'srv-1',
      );
      final today = _session(_thursday, [
        _exercise('Bench', [_set('82,5', '8')]),
      ], planLocalId: 'plan-1');

      expect(
        compareWithPrevious(today, [previous])!.previousSessionId,
        previous.id,
      );
    });

    test('same name but different local ids is a different plan', () {
      final previous = _session(_monday, [
        _exercise('Bench', [_set('80', '8')]),
      ], planLocalId: 'plan-other');
      final today = _session(_thursday, [
        _exercise('Bench', [_set('82,5', '8')]),
      ]);

      final result = compareWithPrevious(today, [previous]);
      expect(result!.kind, WorkoutComparisonKind.firstOfPlan);
    });

    test('ignores the current session and later ones', () {
      final today = _session(_thursday, [
        _exercise('Bench', [_set('82,5', '8')]),
      ]);
      final later = _session(DateTime.utc(2026, 11, 9, 17), [
        _exercise('Bench', [_set('90', '8')]),
      ]);

      final result = compareWithPrevious(today, [today, later]);
      expect(result!.kind, WorkoutComparisonKind.firstOfPlan);
      expect(result.planName, 'Push A');
    });

    test('previous sessions without any completed set are skipped', () {
      final empty = _session(DateTime.utc(2026, 11, 4, 17), [
        _exercise('Bench', [_set('100', '8', completed: false)]),
      ]);
      final previous = _session(_monday, [
        _exercise('Bench', [_set('80', '8')]),
      ]);
      final today = _session(_thursday, [
        _exercise('Bench', [_set('82,5', '8')]),
      ]);

      expect(
        compareWithPrevious(today, [empty, previous])!.previousSessionId,
        previous.id,
      );
    });

    test('nothing completed today means no comparison', () {
      final today = _session(_thursday, [
        _exercise('Bench', [_set('80', '8', completed: false)]),
      ]);
      expect(compareWithPrevious(today, const []), isNull);
    });
  });

  group('exercise results', () {
    ExerciseComparison compareOne(
      List<TrainingSessionSet> before,
      List<TrainingSessionSet> now, {
      ExerciseTracking tracking = ExerciseTracking.weightReps,
    }) {
      final previous = _session(_monday, [
        _exercise('Ex', before, tracking: tracking),
      ]);
      final today = _session(_thursday, [
        _exercise('Ex', now, tracking: tracking),
      ]);
      return compareWithPrevious(today, [previous])!.exercises.single;
    }

    test('heavier top set is an improvement by the weight difference', () {
      final e = compareOne([_set('80', '8')], [_set('82,5', '6')]);
      expect(e.trend, ExerciseTrend.improved);
      expect(e.delta!.kind, DeltaKind.weight);
      expect(e.delta!.value, 2.5);
    });

    test('same weight and more reps is an improvement by reps', () {
      final e = compareOne([_set('30', '9')], [_set('30', '10')]);
      expect(e.trend, ExerciseTrend.improved);
      expect(e.delta!.kind, DeltaKind.reps);
      expect(e.delta!.value, 1);
    });

    test('same top set is "same" even if total reps differ', () {
      final e = compareOne(
        [_set('50', '6')],
        [_set('50', '6'), _set('40', '10')],
      );
      expect(e.trend, ExerciseTrend.same);
      expect(e.delta, isNull);
    });

    test('fewer reps is worse', () {
      final e = compareOne([_set('', '14')], [_set('', '12')]);
      expect(e.trend, ExerciseTrend.worse);
      expect(e.delta!.kind, DeltaKind.reps);
      expect(e.delta!.value, -2);
    });

    test('warmup sets never decide the result', () {
      final e = compareOne(
        [_set('80', '8')],
        [_set('100', '3', type: SetType.warmup), _set('80', '8')],
      );
      expect(e.trend, ExerciseTrend.same);
      expect(e.completedSets, 1);
    });

    test('exercise without any completed set today is skipped', () {
      final previous = _session(_monday, [
        _exercise('Bench', [_set('80', '8')]),
        _exercise('Row', [_set('60', '8')]),
      ]);
      final today = _session(_thursday, [
        _exercise('Bench', [_set('80', '8')]),
        _exercise('Row', [
          _set('60', '8', completed: false),
          _set('60', '8', completed: false),
        ]),
      ]);

      final result = compareWithPrevious(today, [previous])!;
      final row = result.exercises.last;
      expect(row.trend, ExerciseTrend.skipped);
      expect(row.workingSets, 2);
      expect(row.completedSets, 0);
      // Pominięte ćwiczenie nie liczy się do werdyktu.
      expect(result.verdict!.compared, 1);
    });

    test('sets ticked without numbers are not a result', () {
      final blank = TrainingSessionSet(
        plannedWeight: '80',
        plannedReps: '8',
        completed: true,
      );

      // Dziś odhaczone puste serie: bez znaczka i poza werdyktem.
      final previous = _session(_monday, [
        _exercise('Bench', [_set('80', '8')]),
        _exercise('Row', [_set('60', '8')]),
      ]);
      final today = _session(_thursday, [
        _exercise('Bench', [blank, blank]),
        _exercise('Row', [_set('60', '8')]),
      ]);
      final result = compareWithPrevious(today, [previous])!;
      final bench = result.exercises.first;
      expect(bench.trend, ExerciseTrend.skipped);
      expect(bench.delta, isNull);
      expect(bench.completedSets, 2);
      expect(result.verdict!.compared, 1);
      expect(result.verdict!.worse, 0);

      // Poprzednio puste serie: szukamy dalej wstecz, a gdy nic nie ma, to „Nowe”.
      final blankBefore = _session(_monday, [
        _exercise('Bench', [blank, blank]),
        _exercise('Row', [_set('60', '8')]),
      ]);
      final older = _session(DateTime.utc(2026, 10, 26, 17), [
        _exercise('Bench', [_set('77,5', '8')]),
      ]);
      final todayDone = _session(_thursday, [
        _exercise('Bench', [_set('80', '8')]),
        _exercise('Row', [_set('60', '8')]),
      ]);
      final fromOlder = compareWithPrevious(todayDone, [
        blankBefore,
        older,
      ])!.exercises.first;
      expect(fromOlder.previous!.weightKg, 77.5);
      expect(fromOlder.trend, ExerciseTrend.improved);
      expect(fromOlder.delta!.value, 2.5);

      final onlyBlank = compareWithPrevious(todayDone, [blankBefore])!;
      expect(onlyBlank.exercises.first.trend, ExerciseTrend.fresh);
    });

    test('exercise never done before is fresh', () {
      final previous = _session(_monday, [
        _exercise('Bench', [_set('80', '8')]),
      ]);
      final today = _session(_thursday, [
        _exercise('Bench', [_set('80', '8')]),
        _exercise('Row', [_set('50', '10')]),
      ]);
      final result = compareWithPrevious(today, [previous])!;
      expect(result.exercises.last.trend, ExerciseTrend.fresh);
      expect(result.verdict!.fresh, 1);
      // „Nowe” nie wchodzi do mianownika.
      expect(result.verdict!.compared, 1);
    });

    test('exercise is compared with its last performance in any plan', () {
      final planSession = _session(_monday, [
        _exercise('Bench', [_set('80', '8')]),
      ]);
      final otherPlan = _session(
        DateTime.utc(2026, 11, 3, 17),
        [
          _exercise('Bench', [_set('85', '6')]),
        ],
        planLocalId: 'plan-2',
        planName: 'Chest',
      );
      final today = _session(_thursday, [
        _exercise('Bench', [_set('82,5', '8')]),
      ]);

      final e = compareWithPrevious(today, [
        planSession,
        otherPlan,
      ])!.exercises.single;
      // Ostatnie wykonanie to 85 × 6 z innego planu, jak w kolumnie „Poprzednio”.
      expect(e.previous!.weightKg, 85);
      expect(e.trend, ExerciseTrend.worse);
      expect(e.delta!.value, -2.5);
    });

    test('exercise names match case-insensitively', () {
      final previous = _session(_monday, [
        _exercise('bench press', [_set('80', '8')]),
      ]);
      final today = _session(_thursday, [
        _exercise('Bench Press', [_set('82,5', '8')]),
      ]);
      expect(
        compareWithPrevious(today, [previous])!.exercises.single.trend,
        ExerciseTrend.improved,
      );
    });

    test('set rows pair working sets and flag direction', () {
      final e = compareOne(
        [_set('80', '8'), _set('80', '8'), _set('80', '7')],
        [_set('82,5', '8'), _set('80', '8')],
      );
      expect(e.sets.length, 3);
      expect(e.sets[0].direction, 1);
      expect(e.sets[1].direction, 0);
      // Brak dzisiejszej trzeciej serii — nie ma czego oceniać.
      expect(e.sets[2].today, isNull);
      expect(e.sets[2].direction, isNull);
      expect(e.previousVolumeKg, 80 * 8 + 80 * 8 + 80 * 7);
      expect(e.todayVolumeKg, 82.5 * 8 + 80 * 8);
    });

    test('cardio compares distance, and time when there is none', () {
      final distance = compareOne(
        [
          TrainingSessionSet(
            actualDurationSeconds: 1000,
            actualDistanceM: 3200,
            completed: true,
          ),
        ],
        [
          TrainingSessionSet(
            actualDurationSeconds: 1000,
            actualDistanceM: 3600,
            completed: true,
          ),
        ],
        tracking: ExerciseTracking.durationDistance,
      );
      expect(distance.trend, ExerciseTrend.improved);
      expect(distance.delta!.kind, DeltaKind.distance);
      expect(distance.delta!.value, 400);

      final time = compareOne(
        [TrainingSessionSet(actualDurationSeconds: 60, completed: true)],
        [TrainingSessionSet(actualDurationSeconds: 45, completed: true)],
        tracking: ExerciseTracking.duration,
      );
      expect(time.trend, ExerciseTrend.worse);
      expect(time.delta!.kind, DeltaKind.duration);
      expect(time.delta!.value, -15);
    });
  });

  group('verdict', () {
    ComparisonVerdict? verdictOf(
      List<(String, String)> before,
      List<(String, String)> now,
    ) {
      final previous = _session(_monday, [
        for (var i = 0; i < before.length; i++)
          _exercise('Ex$i', [_set(before[i].$1, before[i].$2)]),
      ]);
      final today = _session(_thursday, [
        for (var i = 0; i < now.length; i++)
          _exercise('Ex$i', [_set(now[i].$1, now[i].$2)]),
      ]);
      return compareWithPrevious(today, [previous])!.verdict;
    }

    test('progress when improvements are at least as many as drops', () {
      final v = verdictOf(
        [('80', '8'), ('50', '6'), ('30', '10')],
        [('82,5', '8'), ('50', '6'), ('27,5', '10')],
      )!;
      expect(v.kind, ComparisonVerdictKind.progress);
      expect((v.improved, v.same, v.worse), (1, 1, 1));
    });

    test('everything unchanged', () {
      final v = verdictOf(
        [('80', '8'), ('50', '6')],
        [('80', '8'), ('50', '6')],
      )!;
      expect(v.kind, ComparisonVerdictKind.same);
    });

    test('worse when drops outnumber improvements', () {
      final v = verdictOf(
        [('80', '8'), ('50', '6'), ('30', '10')],
        [('82,5', '8'), ('45', '6'), ('27,5', '10')],
      )!;
      expect(v.kind, ComparisonVerdictKind.worse);
      expect(v.worse, 2);
    });
  });

  group('totals', () {
    test('duration and completed sets come from the sessions', () {
      final previous = _session(_monday, [
        _exercise('Bench', [_set('80', '8'), _set('80', '8')]),
      ], minutes: 62);
      final today = _session(_thursday, [
        _exercise('Bench', [_set('80', '8'), _set('80', '8'), _set('80', '8')]),
      ], minutes: 58);

      final totals = compareWithPrevious(today, [previous])!.totals!;
      expect(totals.setsDelta, 1);
      expect(totals.durationDeltaSeconds, -4 * 60);
      expect(totals.previousDurationSeconds, 62 * 60);
    });
  });

  group('free workout', () {
    test('compares each exercise with its last performance, no totals', () {
      final previous = _free(_monday, [
        _exercise('Row', [_set('70', '8')]),
      ]);
      final today = _free(_thursday, [
        _exercise('Row', [_set('72,5', '8')]),
        _exercise('Curl', [_set('20', '10')]),
      ]);

      final result = compareWithPrevious(today, [previous])!;
      expect(result.kind, WorkoutComparisonKind.lastPerformances);
      expect(result.totals, isNull);
      expect(result.previousSessionId, isNull);
      expect(result.exercises.first.previousDate, _monday);
      expect(result.exercises.first.trend, ExerciseTrend.improved);
      expect(result.exercises.last.trend, ExerciseTrend.fresh);
    });

    test('nothing to show when every exercise is new', () {
      final today = _free(_thursday, [
        _exercise('Row', [_set('72,5', '8')]),
      ]);
      expect(compareWithPrevious(today, const []), isNull);
    });

    test('free workouts are not matched by the default plan name', () {
      final previous = _free(_monday, [
        _exercise('Row', [_set('70', '8')]),
      ]);
      final today = _free(_thursday, [
        _exercise('Row', [_set('72,5', '8')]),
      ]);
      expect(
        compareWithPrevious(today, [previous])!.kind,
        WorkoutComparisonKind.lastPerformances,
      );
    });
  });
}
