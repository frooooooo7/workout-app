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
            today: DateTime(2026, 7, 29), // Środa
            onDaySelected: (day) => selected = day,
          ),
        ),
      ),
    );

    expect(find.text('Pon'), findsOneWidget);
    expect(find.text('Śr'), findsOneWidget);
    expect(find.text('Ndz'), findsOneWidget);
    expect(find.text('29'), findsOneWidget); // dziś

    await tester.tap(find.text('Czw'));
    await tester.pump();
    expect(selected, 4);
  });

  testWidgets('past days show check, future show grey marker key', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingWeekStrip(
            selectedDay: 3,
            today: DateTime(2026, 7, 29),
            onDaySelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('week-indicator-1-past')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-indicator-2-past')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-indicator-3-selected')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-indicator-4-future')), findsOneWidget);
    expect(find.byKey(const ValueKey('week-indicator-7-future')), findsOneWidget);
  });
}
