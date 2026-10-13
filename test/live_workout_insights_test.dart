import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/units/weight_unit.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/services/live_workout_insights.dart';
import 'package:gym/features/training/presentation/widgets/ongoing_workout/next_exercise_card.dart';
import 'package:gym/features/training/presentation/widgets/ongoing_workout/ongoing_workout_header.dart';
import 'package:gym/features/training/presentation/widgets/ongoing_workout/rest_timer_controls.dart';
import 'package:gym/features/training/presentation/widgets/ongoing_workout/workout_progress_header.dart';

TrainingSessionSet _set(
  String weight,
  String reps, {
  bool completed = true,
  SetType type = SetType.normal,
  String planned = '',
}) => TrainingSessionSet(
  setType: type,
  plannedReps: planned,
  actualWeight: weight,
  actualReps: reps,
  completed: completed,
);

void main() {
  setUp(() => WeightUnits.notifier.value = WeightUnit.kg);

  test('formatSetResult uses the decimal comma and the unit', () {
    expect(formatSetResult(92.5, 6), '92,5 × 6');
    expect(formatSetResult(null, 12), '× 12');
    expect(formatSetResult(60, null), '60');
    expect(formatSetResult(null, null), isNull);
    expect(formatSetResult(100, 5, unit: WeightUnit.lb), '220,5 × 5');
  });

  test('topSetOf picks the heaviest working set, more reps on a tie', () {
    final top = topSetOf([
      _set('100', '10', type: SetType.warmup),
      _set('80', '8'),
      _set('82.5', '5'),
      _set('82,5', '6'),
    ]);
    expect(top?.actualReps, '6');
    expect(topSetOf(const []), isNull);
  });

  group('record', () {
    const baseline = ExerciseRecordBaseline(
      weightKg: 92.5,
      weightReps: 6,
      oneRepMaxKg: 111,
    );

    test('a heavier set or a better 1RM beats it', () {
      expect(baseline.isBeatenBy(95, 1), isTrue);
      expect(baseline.isBeatenBy(92.5, 8), isTrue); // e1RM 117
      expect(baseline.isBeatenBy(92.5, 6), isFalse);
      expect(baseline.improvementOf(95, 6), '+2,5 kg');
      expect(baseline.format(), '92,5 × 6');
    });

    test('an empty weight is not a reps record on a weighted exercise', () {
      expect(baseline.isBeatenBy(null, 20), isFalse);
      const bodyweight = ExerciseRecordBaseline(bodyweightReps: 12);
      expect(bodyweight.isBeatenBy(null, 13), isTrue);
      expect(bodyweight.improvementOf(null, 14), '+2 powt.');
    });

    test('the first time an exercise is done is not a record', () {
      expect(const ExerciseRecordBaseline().isBeatenBy(200, 1), isFalse);
    });

    test('later sets must also beat earlier sets of the same workout', () {
      final sets = [
        _set('95', '6'),
        _set('95', '6'),
        _set('97,5', '3', type: SetType.warmup),
        _set('100', '2', completed: false),
      ];
      expect(recordSetIndexes(baseline, sets), {0});
      expect(recordBaselineBefore(baseline, sets, 1).weightKg, 95);
      expect(recordSetIndexes(null, sets), isEmpty);
    });

    test('falls back to the previous workout when history is missing', () {
      final fromPrevious = ExerciseRecordBaseline.fromSets([
        _set('60', '10', type: SetType.warmup),
        _set('80', '8'),
      ]);
      expect(fromPrevious.weightKg, 80);
      expect(fromPrevious.weightReps, 8);
      expect(fromPrevious.isBeatenBy(82.5, 8), isTrue);
    });
  });

  group('progression hint', () {
    test('adds a step when all planned reps were done last time', () {
      final hint = progressionHintFor(
        _set('', '', completed: false, planned: '6-8'),
        _set('92,5', '8'),
      );
      expect(hint?.weightKg, 95);
      expect(hint?.deltaKg, 2.5);
      expect(hint?.isIncrease, isTrue);
    });

    test('repeats the weight when reps fell short', () {
      final hint = progressionHintFor(
        _set('', '', completed: false, planned: '8'),
        _set('92,5', '5'),
      );
      expect(hint?.weightKg, 92.5);
      expect(hint?.isIncrease, isFalse);
    });

    test('warm-ups and sets without a previous weight get none', () {
      expect(
        progressionHintFor(
          _set('', '', completed: false, type: SetType.warmup),
          _set('60', '10'),
        ),
        isNull,
      );
      expect(progressionHintFor(_set('', ''), _set('', '12')), isNull);
    });

    test('uses 5 lb steps in pounds', () {
      expect(progressionStepKg(WeightUnit.lb), closeTo(2.268, 0.001));
    });
  });

  test('progress counts working sets only', () {
    final progress = WorkoutSetProgress.of([
      TrainingSessionExercise(
        exerciseId: 'a',
        exerciseName: 'A',
        exerciseMuscles: const [],
        exerciseCategory: 'compound',
        sets: [
          _set('40', '10', type: SetType.warmup),
          _set('60', '8'),
          _set('60', '8', completed: false),
        ],
      ),
      TrainingSessionExercise(
        exerciseId: 'b',
        exerciseName: 'B',
        exerciseMuscles: const [],
        exerciseCategory: 'compound',
        sets: [_set('20', '10', completed: false)],
      ),
    ]);
    expect(progress.done, 1);
    expect(progress.total, 3);
    expect(progress.fractions, [0.5, 0]);
  });

  test('next exercise plan and time formats', () {
    final exercise = TrainingSessionExercise(
      exerciseId: 'a',
      exerciseName: 'A',
      exerciseMuscles: const [],
      exerciseCategory: 'compound',
      sets: [
        TrainingSessionSet(plannedReps: '10'),
        TrainingSessionSet(plannedReps: '10'),
        TrainingSessionSet(plannedReps: '10'),
      ],
    );
    expect(nextExercisePlan(exercise), '3 × 10');
    expect(
      nextExercisePlan(
        exercise.copyWith(
          sets: [
            TrainingSessionSet(plannedReps: '8'),
            TrainingSessionSet(),
          ],
        ),
      ),
      '2 serie',
    );
    expect(formatElapsed(const Duration(minutes: 24, seconds: 13)), '24:13');
    expect(formatElapsed(const Duration(hours: 1, seconds: 5)), '1:00:05');
    expect(formatRestRemaining(const Duration(seconds: 84)), '1:24');
  });
}
