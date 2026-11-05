import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/services/plan_update_from_session.dart';
import 'package:gym/features/training/presentation/widgets/session_details/session_exercise_card.dart';

const _bench = Exercise(
  id: 'bench',
  name: 'Wyciskanie',
  muscles: [],
  category: ExerciseCategory.compound,
);

const _squat = Exercise(
  id: 'squat',
  name: 'Przysiad',
  muscles: [],
  category: ExerciseCategory.compound,
);

CustomTrainingPlan _plan({bool showRir = true}) => CustomTrainingPlan(
  id: 'plan-1',
  name: 'Push A',
  showRir: showRir,
  exercises: [
    PlanExercise(
      exercise: _bench,
      sets: [
        ExerciseSet(weight: '60', reps: '8', rir: '2'),
        ExerciseSet(weight: '60', reps: '8', rir: '2'),
      ],
    ),
    PlanExercise(
      exercise: _squat,
      sets: [ExerciseSet(weight: '80', reps: '8–12')],
    ),
  ],
);

TrainingSession _done(
  CustomTrainingPlan plan,
  void Function(List<TrainingSessionExercise>) edit,
) {
  final session = TrainingSession.fromPlan(plan);
  final exercises = [
    for (final exercise in session.exercises)
      exercise.copyWith(
        sets: [for (final set in exercise.sets) set.copyWith(completed: true)],
      ),
  ];
  edit(exercises);
  return session.copyWith(exercises: exercises);
}

void main() {
  group('planUpdateFromSession', () {
    test('takes weights and reps from completed sets', () {
      final plan = _plan();
      final session = _done(plan, (exercises) {
        final bench = exercises[0];
        exercises[0] = bench.copyWith(
          sets: [
            bench.sets[0].copyWith(actualWeight: '65', actualReps: '8'),
            bench.sets[1].copyWith(actualWeight: '62,5', actualReps: '10'),
          ],
        );
      });

      final proposal = planUpdateFromSession(plan, session)!;
      final sets = proposal.plan.exercises.first.sets;
      expect(sets.map((s) => s.weight), ['65', '62,5']);
      expect(sets.map((s) => s.reps), ['8', '10']);
      // RIR planu zostaje.
      expect(sets.map((s) => s.rir), ['2', '2']);
      expect(proposal.plan.id, plan.id);
      expect(proposal.changes, hasLength(1));
      expect(proposal.changes.single.exerciseName, 'Wyciskanie');
      expect(proposal.changes.single.before, '60 × 8, 60 × 8');
      expect(proposal.changes.single.after, '65 × 8, 62,5 × 10');
    });

    test('keeps a rep range and unchecked sets', () {
      final plan = _plan();
      final session = _done(plan, (exercises) {
        final bench = exercises[0];
        exercises[0] = bench.copyWith(
          sets: [
            bench.sets[0].copyWith(actualWeight: '70'),
            bench.sets[1].copyWith(actualWeight: '70', completed: false),
          ],
        );
        final squat = exercises[1];
        exercises[1] = squat.copyWith(
          sets: [squat.sets[0].copyWith(actualWeight: '90', actualReps: '10')],
        );
      });

      final proposal = planUpdateFromSession(plan, session)!;
      final bench = proposal.plan.exercises[0].sets;
      expect(bench.map((s) => s.weight), ['70', '60']);
      final squat = proposal.plan.exercises[1].sets.single;
      expect(squat.weight, '90');
      expect(squat.reps, '8–12');
    });

    test('nothing to propose when the workout matched the plan', () {
      final plan = _plan();
      final session = _done(plan, (_) {});
      expect(planUpdateFromSession(plan, session), isNull);
    });
  });

  group('RIR', () {
    test('a plan with RIR turned off does not carry it into the workout', () {
      final session = TrainingSession.fromPlan(_plan(showRir: false));
      final sets = session.exercises.first.sets;
      expect(sets.every((s) => s.plannedRir == null), isTrue);
      expect(sets.every((s) => s.actualRir == null), isTrue);

      final withRir = TrainingSession.fromPlan(_plan());
      expect(withRir.exercises.first.sets.first.actualRir, '2');
    });

    Future<void> pumpCard(
      WidgetTester tester,
      TrainingExerciseDetail exercise, {
      bool hideRir = false,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SessionExerciseCard(
                exercise: exercise,
                index: 0,
                hideRir: hideRir,
              ),
            ),
          ),
        ),
      );
    }

    TrainingExerciseDetail detail({int? rir, String? note}) =>
        TrainingExerciseDetail(
          exerciseId: 'bench',
          exerciseName: 'Wyciskanie',
          note: note,
          sets: [
            TrainingExerciseSetDetail(
              setIndex: 0,
              completed: true,
              actual: TrainingSetMetrics(weightKg: 60, reps: 8, rir: rir),
            ),
          ],
        );

    testWidgets('history hides the RIR column when no set has it', (
      tester,
    ) async {
      await pumpCard(tester, detail());
      expect(find.text('RIR'), findsNothing);

      await pumpCard(tester, detail(rir: 2));
      expect(find.text('RIR'), findsOneWidget);

      // Plan z wyłączonym RIR-em chowa kolumnę nawet przy starych danych.
      await pumpCard(tester, detail(rir: 2), hideRir: true);
      expect(find.text('RIR'), findsNothing);
    });

    testWidgets('history shows the exercise note', (tester) async {
      await pumpCard(tester, detail(note: 'Ławka na 3'));
      expect(find.text('Ławka na 3'), findsOneWidget);
    });
  });
}
