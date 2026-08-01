import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/activity_heatmap.dart';

void main() {
  group('ActivityHeatmap Widget', () {
    testWidgets('renders heatmap with correct summary for month', (tester) async {
      final june2026 = DateTime(2026, 6, 1);
      final trainingDays = {
        DateTime(2026, 6, 5),
        DateTime(2026, 6, 12),
        DateTime(2026, 6, 20),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityHeatmap(
              focusedMonth: june2026,
              trainingDays: trainingDays,
              selectedDay: null,
              onDaySelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Aktywność'), findsOneWidget);
      expect(find.text('3 dni treningowych w czerwcu'), findsOneWidget);
      expect(find.text('Pon'), findsOneWidget);
      expect(find.text('Śro'), findsOneWidget);
      expect(find.text('Pią'), findsOneWidget);
    });

    testWidgets('shows selected day text when day is tapped', (tester) async {
      final july2026 = DateTime(2026, 7, 1);
      final selectedDay = DateTime(2026, 7, 15);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityHeatmap(
              focusedMonth: july2026,
              trainingDays: {selectedDay},
              selectedDay: selectedDay,
              onDaySelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Wybrano 15 lipca'), findsOneWidget);
      expect(find.text('Pokaż cały miesiąc'), findsOneWidget);
    });
  });
}
