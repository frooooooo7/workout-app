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
}
