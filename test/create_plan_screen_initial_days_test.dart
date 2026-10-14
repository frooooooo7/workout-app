import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/repositories/training_plan_repository.dart';
import 'package:gym/features/training/presentation/bloc/training_plans_cubit.dart';
import 'package:gym/features/training/presentation/screens/create_plan_screen.dart';

void main() {
  testWidgets('preselects initial training days for a new plan', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => TrainingPlansCubit(_FakeTrainingPlanRepository()),
          child: const CreatePlanScreen(initialSelectedDays: [2]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('create-plan-day-2-selected')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('create-plan-day-1-idle')),
      findsOneWidget,
    );
  });
  testWidgets('links two exercises into a superset and splits them again', (
    tester,
  ) async {
    await _pumpEditor(tester);

    expect(find.text('SUPERSERIA A'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('plan-link-0')));
    await tester.pumpAndSettle();

    expect(find.text('SUPERSERIA A'), findsOneWidget);
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('Przerwa po rundzie'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-unlink-A')));
    await tester.pumpAndSettle();
    expect(find.text('SUPERSERIA A'), findsNothing);
  });

  testWidgets('the rest chip sets an exercise rest and back to default', (
    tester,
  ) async {
    await _pumpEditor(tester);

    await tester.tap(find.byKey(const ValueKey('plan-rest-chip-0')));
    await tester.pumpAndSettle();
    expect(find.text('Przerwa po serii'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rest-sheet-plus')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rest-sheet-save')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plan-rest-chip-0')),
        matching: find.text('2:15'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('plan-rest-chip-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rest-sheet-default')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plan-rest-chip-0')),
        matching: find.text('2:00'),
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpEditor(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  Exercise exercise(String id) => Exercise(
    id: id,
    name: 'Ćwiczenie $id',
    muscles: const [],
    category: ExerciseCategory.values.first,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider(
        create: (_) => TrainingPlansCubit(_FakeTrainingPlanRepository()),
        child: CreatePlanScreen(
          loadHistory: () async => const [],
          existingPlan: CustomTrainingPlan(
            name: 'Góra A',
            exercises: [
              PlanExercise(exercise: exercise('a')),
              PlanExercise(exercise: exercise('b')),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeTrainingPlanRepository implements TrainingPlanRepository {
  @override
  Future<List<CustomTrainingPlan>> getAll() async => const [];

  @override
  Future<CustomTrainingPlan?> getById(String id) async => null;

  @override
  Future<CustomTrainingPlan> create(CustomTrainingPlan plan) async => plan;

  @override
  Future<CustomTrainingPlan> update(CustomTrainingPlan plan) async => plan;

  @override
  Future<void> delete(String id) async {}
}
