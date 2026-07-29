import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/presentation/widgets/training_today_plan_section.dart';
import 'package:gym/features/training/presentation/widgets/training_week_strip.dart';

void main() {
  CustomTrainingPlan plan(
    String name,
    List<int> days, {
    int exercisesCount = 1,
  }) {
    return CustomTrainingPlan(
      name: name,
      selectedDays: days,
      exercises: [
        for (var i = 0; i < exercisesCount; i++)
          PlanExercise(exercise: mockExercises[i]),
      ],
    );
  }

  testWidgets('rest day: copy, monk, create-plan on tap', (tester) async {
    int? requestedDay;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingTodayPlanSection(
            selectedDay: 2,
            plans: [plan('Push Power', const [1])],
            isLoading: false,
            onDaySelected: (_) {},
            onOpenPlan: (_) {},
            onStartPlan: (_) async {},
            onCreatePlanForDay: (day) => requestedDay = day,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('monk-rest-icon')), findsOneWidget);
    expect(find.text('Dzień odpoczynku'), findsOneWidget);
    expect(find.text('Regeneracja to postęp.'), findsOneWidget);
    expect(find.byKey(const ValueKey('start-workout-button')), findsNothing);

    await tester.tap(find.text('Dzień odpoczynku'));
    await tester.pump();
    expect(requestedDay, 2);
  });

  testWidgets('training day: opens plan on hero tap and starts from button', (
    tester,
  ) async {
    final scheduled = plan('Push Power', const [1, 3]);
    CustomTrainingPlan? opened;
    CustomTrainingPlan? started;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingTodayPlanSection(
            selectedDay: 1,
            plans: [scheduled],
            isLoading: false,
            onDaySelected: (_) {},
            onOpenPlan: (p) => opened = p,
            onStartPlan: (p) async => started = p,
            onCreatePlanForDay: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Dzień treningowy'), findsOneWidget);
    expect(find.text('Push Power'), findsOneWidget);
    expect(find.byKey(const ValueKey('start-workout-button')), findsOneWidget);

    await tester.tap(find.text('Dzień treningowy'));
    await tester.pump();
    expect(opened, same(scheduled));

    await tester.tap(find.byKey(const ValueKey('start-workout-button')));
    await tester.pump();
    expect(started, same(scheduled));
  });

  testWidgets('summarizes additional plans with +N', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingTodayPlanSection(
            selectedDay: 1,
            plans: [
              plan('Push Power', const [1]),
              plan('Pull Volume', const [1, 3]),
            ],
            isLoading: false,
            onDaySelected: (_) {},
            onOpenPlan: (_) {},
            onStartPlan: (_) async {},
            onCreatePlanForDay: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Push Power +1'), findsOneWidget);
  });

  testWidgets('selects day from week strip', (tester) async {
    int? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingTodayPlanSection(
            selectedDay: 2,
            plans: const [],
            isLoading: false,
            onDaySelected: (day) => selected = day,
            onOpenPlan: (_) {},
            onStartPlan: (_) async {},
            onCreatePlanForDay: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(TrainingWeekStrip), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('week-day-4')));
    await tester.pump();
    expect(selected, 4);
  });

  testWidgets('shows loader while plans load', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingTodayPlanSection(
            selectedDay: 3,
            plans: const [],
            isLoading: true,
            onDaySelected: (_) {},
            onOpenPlan: (_) {},
            onStartPlan: (_) async {},
            onCreatePlanForDay: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('monk-rest-icon')), findsNothing);
    expect(find.byKey(const ValueKey('start-workout-button')), findsNothing);
  });
}
