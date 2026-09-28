import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/library/presentation/widgets/library_exercise_grid.dart';

const _exercises = [
  Exercise(
    id: '1',
    name: 'Wypychanie nóg na suwnicy z bardzo długą nazwą ćwiczenia',
    muscles: [MuscleGroup.legs, MuscleGroup.glutes],
    category: ExerciseCategory.calisthenics,
    isPendingSync: true,
  ),
  Exercise(
    id: '2',
    name: 'Plank',
    muscles: [MuscleGroup.abs],
    category: ExerciseCategory.isolation,
    isFavourite: true,
  ),
];

void main() {
  for (final (width, scale) in [(320.0, 1.0), (375.0, 1.3), (768.0, 1.0)]) {
    testWidgets('kafelki mieszczą się: ${width.toInt()} px, tekst ×$scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final tapped = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: LibraryExerciseGrid(
                exercises: _exercises,
                onFavouriteTap: (e) async => tapped.add('fav:${e.id}'),
                onExerciseTap: (e) => tapped.add('open:${e.id}'),
                onMoreTap: (e) => tapped.add('more:${e.id}'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Plank'));
      await tester.tap(find.byTooltip('Dodaj do ulubionych'));
      await tester.tap(find.byTooltip('Więcej').first);
      await tester.pumpAndSettle();
      expect(tapped, ['open:2', 'fav:1', 'more:1']);
    });
  }
}
