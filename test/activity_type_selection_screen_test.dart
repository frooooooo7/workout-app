import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/presentation/screens/activity_type_selection_screen.dart';

void main() {
  testWidgets('shows large image-led activity choice cards', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ActivityTypeSelectionScreen()),
    );

    expect(find.text('Moje plany'), findsOneWidget);
    expect(find.text('Wybierz plan'), findsOneWidget);
    expect(find.text('Niestandardowa'), findsOneWidget);
    expect(find.text('Start od zera'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));

    final planCardSize = tester.getSize(
      find
          .ancestor(
            of: find.text('Moje plany'),
            matching: find.byType(Material),
          )
          .first,
    );

    expect(planCardSize.height, greaterThanOrEqualTo(190));
  });
}
