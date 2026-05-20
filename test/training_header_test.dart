import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/presentation/widgets/training_header.dart';

void main() {
  testWidgets('allows the add button tooltip to match the active tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingHeader(
            addTooltip: 'Utworz plan',
            addLabel: 'Dodaj plan',
            onAddTap: () {},
          ),
        ),
      ),
    );

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip).last);

    expect(tooltip.message, 'Utworz plan');
    expect(find.text('Dodaj plan'), findsOneWidget);
  });

  testWidgets('shows stats button and delegates taps', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingHeader(
            onStatsTap: () => tapped = true,
            onAddTap: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.insert_chart_outlined_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.insert_chart_outlined_rounded));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
