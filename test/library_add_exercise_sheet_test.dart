import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/library/presentation/widgets/library_add_exercise_sheet.dart';

const _bench = Exercise(
  id: '1',
  name: 'Wyciskanie sztangi na ławce',
  muscles: [MuscleGroup.chest],
  category: ExerciseCategory.compound,
);

void main() {
  testWidgets('formularz: ostrzeżenie o duplikacie, sprzęt, inne nazwy i '
      'jak wykonać trafiają do zapisu', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    ExerciseExtras? saved;
    String? savedName;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showLibraryAddExerciseSheet(
                context,
                existing: const [_bench],
                onSubmit: ({
                  required name,
                  required muscles,
                  required category,
                  required description,
                  required tracking,
                  required distanceUnit,
                  required extras,
                  imageBytes,
                  imageFilename,
                }) async {
                  saved = extras;
                  savedName = name;
                  return Exercise(
                    id: 'new',
                    name: name,
                    muscles: muscles,
                    category: category,
                  );
                },
              ),
              child: const Text('otwórz'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('otwórz'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nazwa ćwiczenia'),
      'Wyciskanie na ławce',
    );
    await tester.pump();
    expect(
      find.text('Masz już podobne ćwiczenie: Wyciskanie sztangi na ławce'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Klatka'));
    await tester.tap(find.text('Klatka'));
    await tester.pump();
    await tester.ensureVisible(find.text('Hantle'));
    await tester.tap(find.text('Hantle'));
    await tester.pump();

    await tester.ensureVisible(find.textContaining('Więcej: inne nazwy'));
    await tester.tap(find.textContaining('Więcej: inne nazwy'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Inne nazwy po przecinku, np. DB bench'),
      'DB bench, wyciskanie hantli',
    );
    await tester.enterText(
      find.widgetWithText(
        TextField,
        'Jak wykonać: jeden krok w linii (do 10)',
      ),
      'Połóż się\nWypchnij w górę',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Częste błędy: jeden w linii (do 6)'),
      'Odbijanie od klatki',
    );

    await tester.ensureVisible(find.text('Zapisz'));
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();

    expect(savedName, 'Wyciskanie na ławce');
    expect(saved!.equipment, ExerciseEquipment.dumbbell);
    expect(saved!.aliases, ['DB bench', 'wyciskanie hantli']);
    expect(saved!.instructions!.steps, ['Połóż się', 'Wypchnij w górę']);
    expect(saved!.instructions!.mistakes, ['Odbijanie od klatki']);
  });
}
