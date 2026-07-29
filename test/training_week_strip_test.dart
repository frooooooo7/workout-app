import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/presentation/widgets/training_week_strip.dart';

void main() {
  testWidgets('renders 7 short labels and selects by tap', (tester) async {
    int? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingWeekStrip(
            selectedDay: 3,
            today: DateTime(2026, 7, 29),
            onDaySelected: (day) => selected = day,
          ),
        ),
      ),
    );

    expect(find.text('Pon'), findsOneWidget);
    expect(find.text('Śr'), findsOneWidget);
    expect(find.text('Ndz'), findsOneWidget);
    expect(find.text('29'), findsOneWidget);

    await tester.tap(find.text('Czw'));
    await tester.pump();
    expect(selected, 4);
  });

  testWidgets('shows completed, scheduled and empty markers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingWeekStrip(
            selectedDay: 3,
            today: DateTime(2026, 7, 29),
            scheduledWeekdays: const {1, 2, 4},
            completedWeekdays: const {1},
            onDaySelected: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('week-indicator-1-completed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('week-indicator-2-scheduled')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('week-indicator-3-empty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('week-indicator-4-scheduled')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('week-indicator-5-empty')),
      findsOneWidget,
    );
  });
}
