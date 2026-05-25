import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/presentation/widgets/training_today_plan_section.dart';

void main() {
  testWidgets('shows every plan scheduled for the selected day', (
    tester,
  ) async {
    final plans = [
      CustomTrainingPlan(
        name: 'Push Power',
        selectedDays: const [1],
        exercises: [
          PlanExercise(exercise: mockExercises[0]),
          PlanExercise(exercise: mockExercises[1]),
        ],
      ),
      CustomTrainingPlan(
        name: 'Pull Volume',
        selectedDays: const [1, 3],
        exercises: [PlanExercise(exercise: mockExercises[5])],
      ),
      CustomTrainingPlan(
        name: 'Leg Day',
        selectedDays: const [5],
        exercises: [PlanExercise(exercise: mockExercises[8])],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingTodayPlanSection(
            selectedDay: 1,
            plans: plans,
            isLoading: false,
            onDaySelected: (_) {},
            onOpenPlan: (_) {},
            onStartPlan: (_) async {},
            onCreatePlanForDay: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Push Power'), findsOneWidget);
    expect(find.text('Pull Volume'), findsOneWidget);
    expect(find.text('Leg Day'), findsNothing);
    expect(find.text('2 cwiczenia'), findsOneWidget);
    expect(find.text('1 cwiczenie'), findsOneWidget);
    expect(find.byKey(const ValueKey('week-day-1-has-workout')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-day-3-has-workout')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-day-5-has-workout')), findsOneWidget);
  });

  testWidgets('shows rest day card with create action when no plan matches', (
    tester,
  ) async {
    int? requestedDay;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingTodayPlanSection(
            selectedDay: 2,
            plans: [
              CustomTrainingPlan(
                name: 'Push Power',
                selectedDays: const [1],
                exercises: [PlanExercise(exercise: mockExercises[0])],
              ),
            ],
            isLoading: false,
            onDaySelected: (_) {},
            onOpenPlan: (_) {},
            onStartPlan: (_) async {},
            onCreatePlanForDay: (day) => requestedDay = day,
          ),
        ),
      ),
    );

    expect(find.text('Dzien odpoczynku'), findsOneWidget);
    expect(find.text('Dodaj plan'), findsOneWidget);

    await tester.tap(find.text('Dodaj plan'));
    await tester.pump();

    expect(requestedDay, 2);
  });

  testWidgets('delegates start and open actions for a scheduled plan', (
    tester,
  ) async {
    final plan = CustomTrainingPlan(
      name: 'Push Power',
      selectedDays: const [1],
      exercises: [PlanExercise(exercise: mockExercises[0])],
    );
    CustomTrainingPlan? opened;
    CustomTrainingPlan? started;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingTodayPlanSection(
            selectedDay: 1,
            plans: [plan],
            isLoading: false,
            onDaySelected: (_) {},
            onOpenPlan: (plan) => opened = plan,
            onStartPlan: (plan) async => started = plan,
            onCreatePlanForDay: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Zobacz'));
    await tester.pump();
    expect(opened, same(plan));

    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(started, same(plan));
  });

  testWidgets('does not count all-muscles marker as hidden muscle', (
    tester,
  ) async {
    final plan = CustomTrainingPlan(
      name: 'Full Body',
      selectedDays: const [1],
      exercises: [
        PlanExercise(
          exercise: const Exercise(
            id: 'custom',
            name: 'Combo',
            muscles: [
              MuscleGroup.all,
              MuscleGroup.chest,
              MuscleGroup.back,
              MuscleGroup.legs,
              MuscleGroup.shoulders,
            ],
            category: ExerciseCategory.compound,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingTodayPlanSection(
            selectedDay: 1,
            plans: [plan],
            isLoading: false,
            onDaySelected: (_) {},
            onOpenPlan: (_) {},
            onStartPlan: (_) async {},
            onCreatePlanForDay: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Klatka piersiowa, Plecy, Nogi +1'), findsOneWidget);
    expect(find.text('Klatka piersiowa, Plecy, Nogi +2'), findsNothing);
  });
}
