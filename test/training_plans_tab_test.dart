import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/repositories/training_plan_repository.dart';
import 'package:gym/features/training/presentation/bloc/training_plans_cubit.dart';
import 'package:gym/features/training/presentation/widgets/training_plans_tab.dart';

void main() {
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

  // Poniedziałek — „Push Power” jest planem na dziś.
  final monday = DateTime(2026, 9, 21);

  Future<void> pumpTab(
    WidgetTester tester,
    List<CustomTrainingPlan> plans,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => TrainingPlansCubit(_FakeTrainingPlanRepository(plans)),
          child: Scaffold(body: TrainingPlansTab(now: monday)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the week overview and modern plan cards', (tester) async {
    await pumpTab(tester, plans);

    expect(find.text('Twój tydzień'), findsOneWidget);
    expect(find.text('3/7 dni z planem'), findsOneWidget);
    expect(find.text('Twoje plany'), findsOneWidget);
    expect(find.text('plany'), findsOneWidget);
    expect(find.text('ćwiczeń'), findsOneWidget);
    expect(find.text('Push Power'), findsOneWidget);
    expect(find.text('Leg Day'), findsOneWidget);
    expect(find.text('Ciezkie wyciskania i akcesoria.'), findsOneWidget);
    expect(find.text('DZIŚ'), findsOneWidget);
    expect(find.text('Start'), findsNWidgets(2));
    expect(find.text('2 ćwiczenia · 2 serie'), findsOneWidget);
    expect(find.text('3 ćwiczenia · 3 serie'), findsOneWidget);

    final pushId = plans[0].id;
    expect(find.byKey(ValueKey('plan-day-$pushId-1-selected')), findsOneWidget);
    expect(find.byKey(ValueKey('plan-day-$pushId-3-idle')), findsOneWidget);
  });

  testWidgets('tapping a weekday filters the plan list', (tester) async {
    await pumpTab(tester, plans);

    await tester.tap(find.byKey(const ValueKey('plans-week-day-2')));
    await tester.pumpAndSettle();
    expect(find.text('Wtorek'), findsOneWidget);
    expect(find.text('Leg Day'), findsOneWidget);
    expect(find.text('Push Power'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('plans-week-day-3')));
    await tester.pumpAndSettle();
    expect(find.text('Środa bez planu'), findsOneWidget);

    await tester.tap(find.text('Wszystkie'));
    await tester.pumpAndSettle();
    expect(find.text('Twoje plany'), findsOneWidget);
    expect(find.text('Push Power'), findsOneWidget);
  });

  testWidgets('shows a call to action when there are no plans', (tester) async {
    await pumpTab(tester, const []);

    expect(find.text('Zbuduj pierwszy plan'), findsOneWidget);
    expect(find.text('Utwórz plan'), findsOneWidget);
    expect(find.text('Twój tydzień'), findsNothing);
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
