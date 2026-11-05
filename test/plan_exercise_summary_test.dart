import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/services/plan_exercise_summary.dart';

void main() {
  const bench = Exercise(
    id: 'bench',
    name: 'Wyciskanie',
    muscles: [MuscleGroup.chest],
    category: ExerciseCategory.compound,
  );
  const run = Exercise(
    id: 'run',
    name: 'Bieg',
    muscles: [],
    category: ExerciseCategory.cardio,
    tracking: ExerciseTracking.durationDistance,
  );

  String summary(PlanExercise e) => planExerciseSummary(
    e,
    formatWeight: (raw) => raw!.replaceAll('.', ','),
    weightUnitLabel: 'kg',
  );

  PlanExercise lift(List<(String?, String)> sets) => PlanExercise(
    exercise: bench,
    sets: [for (final (w, r) in sets) ExerciseSet(weight: w, reps: r)],
  );

  test('equal sets collapse to one reps and one weight', () {
    expect(
      summary(lift([('60', '8'), ('60', '8'), ('60', '8'), ('60', '8')])),
      '4 × 8 · 60 kg',
    );
  });

  test('a few different reps are listed, a weight range is shown', () {
    expect(
      summary(lift([('40', '12'), ('45', '10'), ('50', '8')])),
      '3 × 12/10/8 · 40–50 kg',
    );
  });

  test('many different reps become a range', () {
    expect(
      summary(lift([(null, '12'), (null, '10'), (null, '8'), (null, '6')])),
      '4 × 12–6',
    );
  });

  test('sets without reps and weight only count the sets', () {
    expect(summary(lift([(null, ''), (null, '')])), '2 serie');
    expect(summary(lift([(null, '')])), '1 seria');
  });

  test('decimal weights keep the comma and the numeric order', () {
    expect(
      summary(lift([('7.5', '10'), ('10', '10'), ('12.5', '10')])),
      '3 × 10 · 7,5–12,5 kg',
    );
  });

  test('cardio shows segments and total time', () {
    final e = PlanExercise(
      exercise: run,
      sets: [
        ExerciseSet(durationSeconds: 600),
        ExerciseSet(durationSeconds: 900),
      ],
    );
    expect(summary(e), '2 odcinki · 25:00');
  });
}
