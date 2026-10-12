import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/presentation/widgets/training_header.dart';

void main() {
  testWidgets('shows the date and greets by first name', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingHeader(
            firstName: 'Damian',
            today: DateTime(2026, 10, 15),
            showSync: false,
          ),
        ),
      ),
    );

    expect(find.text('CZWARTEK, 15 PAŹDZIERNIKA'), findsOneWidget);
    expect(find.text('Cześć, Damian'), findsOneWidget);
  });

  testWidgets('falls back to a plain greeting without a name', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TrainingHeader(showSync: false))),
    );

    expect(find.text('Cześć'), findsOneWidget);
  });

  testWidgets('shows library button and delegates taps', (tester) async {
    var libraryTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrainingHeader(
            showSync: false,
            onLibraryTap: () => libraryTapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pump();

    expect(libraryTapped, isTrue);
  });
}
