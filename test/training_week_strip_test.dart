import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';
import 'package:gym/features/training/presentation/widgets/training_week_strip.dart';

// Środa 2026-07-29; tydzień 27.07–2.08.
final _today = DateTime(2026, 7, 29, 9);

Future<void> _pump(
  WidgetTester tester, {
  int selectedDay = 3,
  Map<int, String> scheduled = const {},
  Map<int, String> done = const {},
  WeeklyGoalProgress? goal,
  ValueChanged<int>? onDaySelected,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TrainingWeekStrip(
          selectedDay: selectedDay,
          today: _today,
          scheduledPlans: scheduled,
          donePlans: done,
          weeklyGoal: goal,
          onDaySelected: onDaySelected ?? (_) {},
        ),
      ),
    ),
  );
}

Finder _circle(int weekday, WeekDayState state) => find.descendant(
  of: find.byKey(ValueKey('week-day-$weekday')),
  matching: find.byKey(ValueKey('week-circle-${state.name}')),
);

void main() {
  testWidgets('renders day states and captions', (tester) async {
    await _pump(
      tester,
      scheduled: const {1: 'Push', 3: 'Legs', 5: 'Pull', 6: 'Legs'},
      done: const {1: 'Push', 2: 'Pull'},
    );

    expect(_circle(1, WeekDayState.done), findsOneWidget);
    expect(_circle(2, WeekDayState.done), findsOneWidget);
    expect(_circle(3, WeekDayState.today), findsOneWidget);
    expect(_circle(4, WeekDayState.rest), findsOneWidget);
    expect(_circle(5, WeekDayState.planned), findsOneWidget);
    expect(_circle(7, WeekDayState.rest), findsOneWidget);

    expect(find.text('dziś'), findsOneWidget);
    expect(find.text('Pull'), findsOneWidget);
    expect(find.text('Legs'), findsOneWidget);
    expect(find.text('wolne'), findsNWidgets(2));
    // Minione dni podpisane datą.
    expect(find.text('27'), findsOneWidget);
    expect(find.text('Ten tydzień'), findsOneWidget);
    expect(find.text('2 z 4 treningów'), findsOneWidget);
    expect(find.bySemanticsLabel('Środa 29, dziś Legs'), findsOneWidget);
  });

  testWidgets('marks a missed planned day instead of repeating its date', (
    tester,
  ) async {
    await _pump(tester, scheduled: const {1: 'Push'}, done: const {});

    expect(find.text('brak'), findsOneWidget);
  });

  testWidgets('uses the weekly goal and shows the streak', (tester) async {
    await _pump(
      tester,
      done: const {1: 'Push'},
      goal: const WeeklyGoalProgress(
        goal: 3,
        workoutsThisWeek: 1,
        weeks: [],
        streakWeeks: 11,
        bestStreakWeeks: 11,
        daysLeft: 4,
      ),
    );

    expect(find.text('1 z 3 treningów'), findsOneWidget);
    expect(find.text('11 tyg.'), findsOneWidget);
  });

  testWidgets('selects a day by tap', (tester) async {
    int? selected;
    await _pump(tester, onDaySelected: (day) => selected = day);

    await tester.tap(find.byKey(const ValueKey('week-day-4')));
    await tester.pump();
    expect(selected, 4);
  });
}
