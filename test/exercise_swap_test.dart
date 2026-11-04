import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/services/exercise_swap.dart';

const _dumbbell = Exercise(
  id: 'db',
  name: 'Wyciskanie hantli na ławce',
  muscles: [MuscleGroup.chest],
  category: ExerciseCategory.compound,
);

TrainingSessionExercise _ex(
  String id,
  List<bool> completed, {
  String? group,
}) => TrainingSessionExercise(
  id: id,
  exerciseId: 'ex-$id',
  exerciseName: 'Ćwiczenie $id',
  exerciseMuscles: const ['chest'],
  exerciseCategory: 'compound',
  supersetGroup: group,
  sets: [for (final c in completed) TrainingSessionSet(completed: c)],
);

void main() {
  test('bez zrobionych serii nowe ćwiczenie staje na miejscu starego', () {
    final list = [_ex('a', [false, false, false], group: 'A'), _ex('b', [false])];
    final result = ExerciseSwap.apply(list, 'a', _dumbbell)!;
    expect(result.exercises, hasLength(2));
    final swapped = result.exercises.first;
    expect(swapped.exerciseId, 'db');
    expect(swapped.sets, hasLength(3));
    expect(swapped.supersetGroup, 'A');
    expect(swapped.id, result.newExerciseId);
    expect(result.exercises[1].id, 'b');
  });

  test('zrobione serie zostają przy starym, nowe dostaje resztę', () {
    final list = [_ex('a', [true, false, false]), _ex('b', [false])];
    final result = ExerciseSwap.apply(list, 'a', _dumbbell)!;
    expect(result.exercises, hasLength(3));
    expect(result.exercises[0].id, 'a');
    expect(result.exercises[0].sets, hasLength(1));
    expect(result.exercises[0].sets.single.completed, isTrue);
    expect(result.exercises[1].exerciseId, 'db');
    expect(result.exercises[1].sets, hasLength(2));
    expect(result.exercises[1].id, result.newExerciseId);
    expect(result.exercises[2].id, 'b');
  });

  test('wszystkie serie zrobione: nowe ćwiczenie ma jedną serię', () {
    final result = ExerciseSwap.apply([
      _ex('a', [true, true]),
    ], 'a', _dumbbell)!;
    expect(result.exercises[1].sets, hasLength(1));
  });

  test('nieznane ćwiczenie zwraca null', () {
    expect(ExerciseSwap.apply([_ex('a', [false])], 'zzz', _dumbbell), isNull);
  });
}
