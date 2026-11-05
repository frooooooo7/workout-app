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

  test('zamiana ciężaru na same powtórzenia: nowe serie są puste, bez wagi', () {
    final weighted = TrainingSessionExercise(
      id: 'a',
      exerciseId: 'ex-a',
      exerciseName: 'Wyciskanie',
      exerciseMuscles: const ['chest'],
      exerciseCategory: 'compound',
      sets: [
        TrainingSessionSet(plannedWeight: '80', plannedReps: '5'),
        TrainingSessionSet(plannedWeight: '80', plannedReps: '5'),
      ],
    );
    const pushups = Exercise(
      id: 'pu',
      name: 'Pompki',
      muscles: [MuscleGroup.chest],
      category: ExerciseCategory.compound,
      tracking: ExerciseTracking.reps,
    );
    final result = ExerciseSwap.apply([weighted], 'a', pushups)!;
    final swapped = result.exercises.single;
    expect(swapped.tracking, ExerciseTracking.reps);
    expect(swapped.sets, hasLength(2));
    expect(swapped.sets.every((s) => s.plannedWeight == null), isTrue);
    // Powtórzenia zostają, ciężar jest czyszczony.
    expect(swapped.sets.every((s) => s.plannedReps == '5'), isTrue);
  });

  test('serie zachowują typ, powtórzenia, RIR i tempo; czas zaczyna od zera', () {
    final weighted = TrainingSessionExercise(
      id: 'a',
      exerciseId: 'ex-a',
      exerciseName: 'Wyciskanie',
      exerciseMuscles: const ['chest'],
      exerciseCategory: 'compound',
      sets: [
        TrainingSessionSet(
          setType: SetType.warmup,
          plannedWeight: '40',
          plannedReps: '8–12',
          plannedRir: '2',
          plannedTempo: '3-1-1',
        ),
      ],
    );
    final carried = ExerciseSwap.apply([weighted], 'a', _dumbbell)!
        .exercises
        .single
        .sets
        .single;
    expect(carried.setType, SetType.warmup);
    expect(carried.plannedReps, '8–12');
    expect(carried.plannedRir, '2');
    expect(carried.plannedTempo, '3-1-1');
    expect(carried.plannedWeight, isNull);

    const plank = Exercise(
      id: 'plank',
      name: 'Deska',
      muscles: [MuscleGroup.abs],
      category: ExerciseCategory.isolation,
      tracking: ExerciseTracking.duration,
    );
    final empty = ExerciseSwap.apply([weighted], 'a', plank)!
        .exercises
        .single
        .sets
        .single;
    expect(empty.plannedReps, isEmpty);
    expect(empty.setType, SetType.normal);
  });

  test('cofnięcie zamiany zostawia serie odhaczone w międzyczasie', () {
    final list = [_ex('a', [true, false, false]), _ex('b', [false])];
    final swap = ExerciseSwap.apply(list, 'a', _dumbbell)!;
    // W międzyczasie odhaczona seria w ćwiczeniu „b”.
    final ticked = [
      for (final e in swap.exercises)
        e.id == 'b'
            ? e.copyWith(sets: [e.sets.single.copyWith(completed: true)])
            : e,
    ];
    final undone = ExerciseSwap.undo(ticked, swap)!;
    expect(undone.map((e) => e.id), ['a', 'b']);
    expect(undone[0].sets, hasLength(3));
    expect(undone[1].sets.single.completed, isTrue);
  });

  test('cofnięcie zamiany w miejscu przywraca oryginał', () {
    final list = [_ex('a', [false, false]), _ex('b', [false])];
    final swap = ExerciseSwap.apply(list, 'a', _dumbbell)!;
    final undone = ExerciseSwap.undo(swap.exercises, swap)!;
    expect(undone.map((e) => e.id), ['a', 'b']);
    expect(undone[0].sets, hasLength(2));
    expect(ExerciseSwap.undo(list, swap), isNull);
  });
}
