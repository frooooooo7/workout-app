import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/presentation/screens/training_stats_screen.dart';

void main() {
  testWidgets('renders full screen activity summary', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TrainingStatsScreen(),
      ),
    );

    expect(find.text('Statystyki'), findsOneWidget);
    expect(find.text('Podsumowanie aktywnosci'), findsOneWidget);
    expect(find.text('Tydzien'), findsOneWidget);
    expect(find.text('Miesiac'), findsOneWidget);
  });
}
