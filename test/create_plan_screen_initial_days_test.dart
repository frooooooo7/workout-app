import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.byKey(const ValueKey('create-plan-day-1-idle')), findsOneWidget);
  });
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
