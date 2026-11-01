import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/post_draft.dart';
import 'package:gym/features/training/domain/repositories/training_plan_repository.dart';
import 'package:gym/features/training/presentation/bloc/training_plans_cubit.dart';
import 'package:gym/features/training/presentation/bloc/training_session_cubit.dart';
import 'package:gym/features/training/presentation/screens/plan_details_screen.dart';

void main() {
  Exercise exercise(String id, String name) => Exercise(
    id: id,
    name: name,
    muscles: const [MuscleGroup.chest],
    category: ExerciseCategory.compound,
  );

  final plan = CustomTrainingPlan(
    name: 'Push A',
    note: 'Wolne ekscentryki',
    selectedDays: const [1, 4],
    goal: PlanGoal.hypertrophy,
    exercises: [
      PlanExercise(
        exercise: exercise('1', 'Wyciskanie sztangi'),
        sets: [
          ExerciseSet(weight: '80', reps: '8'),
          ExerciseSet(weight: '80', reps: '8'),
        ],
      ),
      PlanExercise(
        exercise: exercise('2', 'Rozpiętki'),
        supersetGroup: 'A',
        sets: [ExerciseSet(weight: '20', reps: '12')],
      ),
      PlanExercise(
        exercise: exercise('3', 'Pompki'),
        supersetGroup: 'A',
        sets: [ExerciseSet(reps: '15')],
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, CustomTrainingPlan plan) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final cubit = TrainingPlansCubit(_Repo([plan]));
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        home: PlanDetailsScreen(
          args: PlanDetailsArgs(
            plan: plan,
            cubit: cubit,
            sessionCubit: _FakeSessionCubit(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the plan summary and compact exercise rows', (
    tester,
  ) async {
    await pump(tester, plan);

    expect(find.byKey(const ValueKey('plan-hero-name')), findsOneWidget);
    expect(find.text('Masa · ~10 min'), findsOneWidget);
    expect(find.text('Wolne ekscentryki'), findsOneWidget);
    expect(find.text('Wyciskanie sztangi'), findsOneWidget);
    expect(find.text('2 × 8 · 80 kg'), findsOneWidget);
    expect(find.text('SUPERSERIA A'), findsOneWidget);
    // Serie są schowane, dopóki nie rozwiniemy ćwiczenia.
    expect(find.text('CIĘŻAR'), findsNothing);

    await tester.tap(find.text('Wyciskanie sztangi'));
    await tester.pumpAndSettle();
    expect(find.text('CIĘŻAR'), findsOneWidget);
    expect(find.textContaining('Przerwa po serii'), findsOneWidget);
  });

  testWidgets('the start button is disabled for a plan without exercises', (
    tester,
  ) async {
    await pump(tester, CustomTrainingPlan(name: 'Pusty'));

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('plan-details-start')),
    );
    expect(button.onPressed, isNull);
  });
}

class _Repo implements TrainingPlanRepository {
  _Repo(this.plans);

  final List<CustomTrainingPlan> plans;

  @override
  Future<List<CustomTrainingPlan>> getAll() async => plans;

  @override
  Future<CustomTrainingPlan?> getById(String id) async => null;

  @override
  Future<CustomTrainingPlan> create(
    CustomTrainingPlan plan, {
    PostPhotoChange cover = const KeepPostPhoto(),
  }) async => plan;

  @override
  Future<CustomTrainingPlan> update(
    CustomTrainingPlan plan, {
    PostPhotoChange cover = const KeepPostPhoto(),
  }) async => plan;

  @override
  Future<void> reorder(List<String> orderedIds) async {}

  @override
  Future<void> delete(String id) async {}
}

class _FakeSessionCubit implements TrainingSessionCubit {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
