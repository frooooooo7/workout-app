import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/repositories/training_plan_repository.dart';
import 'package:gym/features/training/presentation/bloc/training_plans_cubit.dart';
import 'package:gym/features/training/presentation/widgets/training_plans_tab.dart';

void main() {
  testWidgets('shows a dashboard summary and modern plan cards', (
    tester,
  ) async {
    final plans = [
      CustomTrainingPlan(
        name: 'Push Power',
        note: 'Ciezkie wyciskania i akcesoria.',
        selectedDays: const [1, 4],
        exercises: [
          PlanExercise(exercise: mockExercises[0]),
          PlanExercise(exercise: mockExercises[3]),
        ],
      ),
      CustomTrainingPlan(
        name: 'Leg Day',
        selectedDays: const [2],
        exercises: [
          PlanExercise(exercise: mockExercises[2]),
          PlanExercise(exercise: mockExercises[8]),
          PlanExercise(exercise: mockExercises[13]),
        ],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => TrainingPlansCubit(_FakeTrainingPlanRepository(plans)),
          child: const Scaffold(body: TrainingPlansTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Twoje plany'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Push Power'), findsOneWidget);
    expect(find.text('Leg Day'), findsOneWidget);
    expect(find.text('Ciezkie wyciskania i akcesoria.'), findsOneWidget);
    expect(find.text('Otworz'), findsNWidgets(2));
    expect(find.text('Utworz plan'), findsNothing);
    expect(find.text('Pn'), findsNothing);
    expect(find.text('Wt'), findsNothing);

    expect(
      find.byKey(const ValueKey('plan-day-dot-1-selected')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('plan-day-dot-3-idle')), findsWidgets);
  });
}

class _FakeTrainingPlanRepository implements TrainingPlanRepository {
  _FakeTrainingPlanRepository(this._plans);

  final List<CustomTrainingPlan> _plans;

  @override
  Future<List<CustomTrainingPlan>> getAll() async => _plans;

  @override
  Future<CustomTrainingPlan?> getById(String id) async {
    for (final plan in _plans) {
      if (plan.id == id) return plan;
    }
    return null;
  }

  @override
  Future<CustomTrainingPlan> create(CustomTrainingPlan plan) async => plan;

  @override
  Future<CustomTrainingPlan> update(CustomTrainingPlan plan) async => plan;

  @override
  Future<void> delete(String id) async {}
}
