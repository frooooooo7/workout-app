import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/presentation/widgets/training_header.dart';

void main() {
  testWidgets('allows the add button tooltip to be customized', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingHeader(
            addTooltip: 'Dodaj trening',
            onAddTap: () {},
          ),
        ),
      ),
    );

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip).last);

    expect(tooltip.message, 'Dodaj trening');
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('shows library button and delegates taps', (tester) async {
    var libraryTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingHeader(
            onLibraryTap: () => libraryTapped = true,
            onAddTap: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.format_list_bulleted_rounded), findsNothing);
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pump();

    expect(libraryTapped, isTrue);
  });
}
