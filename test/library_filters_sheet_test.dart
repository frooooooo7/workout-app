import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/library/presentation/widgets/library_filters_sheet.dart';

void main() {
  testWidgets('arkusz filtrów: wybór mięśnia, sprzętu i typu, „Wyczyść”', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    LibraryFilterSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showLibraryFiltersSheet(
                context,
                selected: const LibraryFilterSelection(
                  equipment: {ExerciseEquipment.band},
                ),
                // Każdy wybrany filtr „zostawia” 5 ćwiczeń mniej niż 12.
                countFor: (s) =>
                    12 - s.muscles.length - s.equipment.length - s.types.length,
              ),
              child: const Text('otwórz'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('otwórz'));
    await tester.pumpAndSettle();

    expect(find.text('Pokaż 11 ćwiczeń'), findsOneWidget);
    await tester.tap(find.text('Wyczyść'));
    await tester.pump();
    expect(find.text('Pokaż 12 ćwiczeń'), findsOneWidget);

    await tester.tap(find.text('Biceps'));
    await tester.scrollUntilVisible(
      find.text('Hantle'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Hantle'));
    await tester.scrollUntilVisible(
      find.text(ExerciseCategory.isolation.label),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text(ExerciseCategory.isolation.label));
    await tester.pump();
    expect(find.text('Pokaż 9 ćwiczeń'), findsOneWidget);

    await tester.tap(find.text('Pokaż 9 ćwiczeń'));
    await tester.pumpAndSettle();
    expect(result!.muscles, {MuscleGroup.biceps});
    expect(result!.equipment, {ExerciseEquipment.dumbbell});
    expect(result!.types, {ExerciseCategory.isolation});
  });
}
