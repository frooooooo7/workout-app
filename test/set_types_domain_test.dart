import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/library/domain/models/exercise_stats.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/repositories/previous_performance_repository.dart';
import 'package:gym/features/training/domain/services/repeat_training_session.dart';
import 'package:gym/features/training/domain/services/training_session_detail_mapper.dart';
import 'package:gym/features/training/domain/services/training_summary_calculator.dart';
import 'package:gym/features/training/domain/services/workout_edit.dart';

TrainingSessionSet _set(
  String weight,
  String reps, {
  SetType type = SetType.normal,
  bool completed = true,
}) => TrainingSessionSet(
  setType: type,
  actualWeight: weight,
  actualReps: reps,
  completed: completed,
);

TrainingSessionExercise _exercise(
  List<TrainingSessionSet> sets, {
  String? note,
}) => TrainingSessionExercise(
  exerciseId: 'bench',
  exerciseName: 'Bench',
  exerciseMuscles: const ['chest'],
  exerciseCategory: 'compound',
  note: note,
  sets: sets,
);

TrainingSession _session(
  List<TrainingSessionExercise> exercises, {
  DateTime? startedAt,
}) {
  final start = startedAt ?? DateTime.utc(2026, 9, 10, 10);
  return TrainingSession(
    planName: 'Push',
    status: TrainingSessionStatus.completed,
    startedAt: start,
    finishedAt: start.add(const Duration(hours: 1)),
    exercises: exercises,
  );
}

void main() {
  group('SetType', () {
    test(
      'parse falls back to normal for unknown, empty or non-string values',
      () {
        expect(SetType.parse('warmup'), SetType.warmup);
        expect(SetType.parse('failure'), SetType.failure);
        expect(SetType.parse('drop'), SetType.drop);
        expect(SetType.parse('normal'), SetType.normal);
        expect(SetType.parse('superset'), SetType.normal);
        expect(SetType.parse(null), SetType.normal);
        expect(SetType.parse(3), SetType.normal);
      },
    );

    test('only warm-ups are excluded from statistics', () {
      expect(SetType.warmup.countsTowardStats, isFalse);
      for (final type in [SetType.normal, SetType.failure, SetType.drop]) {
        expect(type.countsTowardStats, isTrue, reason: type.name);
      }
    });

    test('apiName matches the value the backend expects', () {
      expect(SetType.values.map((t) => t.apiName), [
        'normal',
        'warmup',
        'failure',
        'drop',
      ]);
    });

    test('row labels number working sets and letter the others', () {
      expect(
        setRowLabels([
          SetType.warmup,
          SetType.normal,
          SetType.normal,
          SetType.failure,
          SetType.drop,
          SetType.normal,
        ]),
        ['W', '1', '2', 'F', 'D', '3'],
      );
      expect(setRowLabels(const []), isEmpty);
    });
  });

  group('warm-ups do not count toward statistics', () {
    test(
      'summary calculator skips them in sets, reps, volume and exercises',
      () {
        final stats = TrainingSummaryCalculator.aggregate([
          _session([
            _exercise([
              _set('120', '1', type: SetType.warmup),
              _set('100', '5'),
              _set('100', '4', type: SetType.failure),
            ]),
            // Ćwiczenie tylko z rozgrzewką nie liczy się jako wykonane.
            TrainingSessionExercise(
              exerciseId: 'row',
              exerciseName: 'Row',
              exerciseMuscles: const ['lats'],
              exerciseCategory: 'compound',
              sets: [_set('20', '10', type: SetType.warmup)],
            ),
          ]),
        ]);

        expect(stats.completedSets, 2);
        expect(stats.reps, 9);
        expect(stats.volumeKg, 100 * 5 + 100 * 4);
        expect(stats.distinctExercises, 1);
      },
    );

    test('exercise stats ignore them for records, 1RM and volume', () {
      const bench = Exercise(
        id: 'bench',
        name: 'Bench',
        muscles: [MuscleGroup.chest],
        category: ExerciseCategory.compound,
      );
      final stats = ExerciseStats.fromSessions(bench, [
        _session([
          _exercise([_set('150', '1', type: SetType.warmup), _set('100', '5')]),
        ]),
      ]);

      expect(stats.bestWeightKg, 100);
      expect(stats.bestWeightReps, 5);
      expect(stats.totalSets, 1);
      expect(stats.totalVolumeKg, 500);
      expect(stats.history.single.topWeightKg, 100);
    });

    test('an exercise done only as warm-ups has no stats and no usage', () {
      const bench = Exercise(
        id: 'bench',
        name: 'Bench',
        muscles: [MuscleGroup.chest],
        category: ExerciseCategory.compound,
      );
      final sessions = [
        _session([
          _exercise([_set('40', '10', type: SetType.warmup)]),
        ]),
      ];

      expect(ExerciseStats.fromSessions(bench, sessions).hasData, isFalse);
      expect(ExerciseStats.usage(sessions).countFor(bench), 0);
    });

    test('history read model: volume, count, top set and denominator', () {
      final detail = trainingSessionDetailFromSession(
        _session([
          _exercise([
            _set('120', '1', type: SetType.warmup),
            _set('100', '5'),
            _set('90', '8', type: SetType.drop),
            _set('80', '10', completed: false),
          ]),
        ]),
      );
      final exercise = detail.exercises.single;

      expect(exercise.sets.map((s) => s.setType), [
        SetType.warmup,
        SetType.normal,
        SetType.drop,
        SetType.normal,
      ]);
      expect(exercise.completedSetsCount, 2);
      expect(exercise.workingSetsCount, 3);
      expect(exercise.volumeKg, 100 * 5 + 90 * 8);
      expect(exercise.topSet?.actual?.weightKg, 100);
      expect(detail.completedSetsCount, 2);
      expect(detail.workingSetsCount, 3);
      expect(detail.totalVolumeKg, 1220);
    });

    test('the detail mapper carries the exercise note', () {
      final detail = trainingSessionDetailFromSession(
        _session([
          _exercise([_set('100', '5')], note: 'Ławka o 1 dziurkę niżej'),
        ]),
      );
      expect(detail.exercises.single.note, 'Ławka o 1 dziurkę niżej');
    });
  });

  group('editing a finished workout', () {
    test('keeps every set type and normalizes the exercise note', () {
      final original = _session([
        _exercise([
          _set('120', '1', type: SetType.warmup),
          _set('100', '5', type: SetType.failure),
          _set('80', '8', type: SetType.drop),
        ], note: '  z pauzą  '),
        _exercise(const [], note: null),
      ]);
      final edited = applyWorkoutEdit(
        original,
        WorkoutEditDraft.fromSession(original).copyWith(
          exercises: [
            original.exercises.first,
            original.exercises.first.copyWith(note: '   ', id: 'other'),
          ],
        ),
      );

      expect(edited.exercises.first.sets.map((s) => s.setType), [
        SetType.warmup,
        SetType.failure,
        SetType.drop,
      ]);
      expect(edited.exercises.first.note, 'z pauzą');
      expect(edited.exercises.last.note, isNull);
    });

    test('rejects an exercise note longer than the API allows', () {
      final original = _session([
        _exercise([_set('100', '5')], note: 'x' * (maxExerciseNoteLength + 1)),
      ]);
      final error = validateWorkoutEdit(
        WorkoutEditDraft.fromSession(original),
        now: DateTime.utc(2026, 9, 11),
      );
      expect(error, contains('Notatka do ćwiczenia'));

      final ok = _session([
        _exercise([_set('100', '5')], note: 'x' * maxExerciseNoteLength),
      ]);
      expect(
        validateWorkoutEdit(
          WorkoutEditDraft.fromSession(ok),
          now: DateTime.utc(2026, 9, 11),
        ),
        isNull,
      );
    });
  });

  group('repeating a workout', () {
    test('keeps set types but not the exercise note', () {
      final repeated = buildRepeatedSession(
        _session([
          _exercise([
            _set('60', '10', type: SetType.warmup),
            _set('100', '5'),
          ], note: 'Ławka o 1 dziurkę niżej'),
        ]),
      );

      final exercise = repeated.exercises.single;
      expect(exercise.sets.map((s) => s.setType), [
        SetType.warmup,
        SetType.normal,
      ]);
      expect(exercise.note, isNull);
      expect(exercise.sets.every((s) => !s.completed), isTrue);
    });
  });

  group('previous performance matching', () {
    final previous = [
      _set('60', '10', type: SetType.warmup),
      _set('100', '5'),
      _set('100', '4', type: SetType.failure),
    ];

    test('warm-ups match warm-ups and working sets match working sets', () {
      final current = [
        _set('', '', type: SetType.warmup),
        _set('', ''),
        _set('', ''),
      ];
      expect(previousSetFor(current, 0, previous)?.actualWeight, '60');
      expect(previousSetFor(current, 1, previous)?.actualWeight, '100');
      expect(previousSetFor(current, 1, previous)?.actualReps, '5');
      expect(previousSetFor(current, 2, previous)?.actualReps, '4');
    });

    test('an extra warm-up does not shift the working-set comparison', () {
      final current = [
        _set('', '', type: SetType.warmup),
        _set('', '', type: SetType.warmup),
        _set('', ''),
      ];
      // Druga rozgrzewka nie ma odpowiednika, a seria robocza dalej pasuje
      // do pierwszej roboczej sprzed tygodnia.
      expect(previousSetFor(current, 1, previous), isNull);
      expect(previousSetFor(current, 2, previous)?.actualReps, '5');
    });

    test('returns null when there were fewer sets of that kind', () {
      final current = [_set('', ''), _set('', ''), _set('', ''), _set('', '')];
      expect(previousSetFor(current, 3, previous), isNull);
      expect(previousSetFor([_set('', '')], 0, const []), isNull);
    });

    test('formatPreviousSet shows weight × reps and tolerates gaps', () {
      expect(formatPreviousSet(_set('82,5', '8')), '82,5×8');
      expect(formatPreviousSet(_set('', '12')), '×12');
      expect(formatPreviousSet(_set('60', '')), '60');
      expect(formatPreviousSet(_set('  ', '  ')), isNull);
      expect(formatPreviousSet(null), isNull);
    });
  });
}
