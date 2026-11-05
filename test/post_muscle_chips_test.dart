import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/feed/presentation/widgets/post_muscle_chips.dart';
import 'package:gym/features/library/domain/models/exercise.dart';

void main() {
  testWidgets('specific muscles collapse into one chip per broad group', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PostMuscleChips(
            muscles: [
              MuscleGroup.chest,
              MuscleGroup.triceps,
              MuscleGroup.frontDelts,
              MuscleGroup.sideDelts,
            ],
          ),
        ),
      ),
    );

    expect(find.text(MuscleGroup.chest.shortLabel), findsOneWidget);
    expect(find.text(MuscleGroup.triceps.shortLabel), findsOneWidget);
    expect(find.text(MuscleGroup.shoulders.shortLabel), findsOneWidget);
    expect(find.text(MuscleGroup.frontDelts.shortLabel), findsNothing);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('forearms are not shown as biceps', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PostMuscleChips(
            muscles: [MuscleGroup.forearms, MuscleGroup.biceps],
          ),
        ),
      ),
    );

    expect(find.text(MuscleGroup.forearms.shortLabel), findsOneWidget);
    expect(find.text(MuscleGroup.biceps.shortLabel), findsOneWidget);
  });
}
