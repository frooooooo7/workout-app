import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/presentation/screens/plan_details_screen.dart';

void main() {
  test('kopia planu ma nowe identyfikatory, te same serie i brak dni', () {
    final original = CustomTrainingPlan(
      name: 'Push',
      note: 'Ciężko',
      selectedDays: const [1, 4],
      clientId: 'client-1',
      exercises: [
        PlanExercise(
          exercise: const Exercise(
            id: 'bench',
            name: 'Wyciskanie',
            muscles: [MuscleGroup.chest],
            category: ExerciseCategory.compound,
          ),
          sets: [
            ExerciseSet(weight: '80', reps: '8', rir: '2'),
            ExerciseSet(weight: '85', reps: '6', tempo: '3010'),
          ],
        ),
      ],
    );

    final copy = duplicatePlan(original);

    expect(copy.id, isNot(original.id));
    expect(copy.clientId, isNull);
    expect(copy.name, 'Push (kopia)');
    expect(copy.note, 'Ciężko');
    expect(copy.selectedDays, isEmpty);

    final copiedExercise = copy.exercises.single;
    final originalExercise = original.exercises.single;
    expect(copiedExercise.id, isNot(originalExercise.id));
    expect(copiedExercise.exercise.id, 'bench');
    expect(
      copiedExercise.sets.map((s) => (s.weight, s.reps, s.rir, s.tempo)),
      [('80', '8', '2', null), ('85', '6', null, '3010')],
    );
    for (var i = 0; i < copiedExercise.sets.length; i++) {
      expect(copiedExercise.sets[i].id, isNot(originalExercise.sets[i].id));
    }
  });
}
