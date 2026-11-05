import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/library/presentation/screens/swap_exercise_screen.dart';

const _bench = Exercise(
  id: 'bench',
  name: 'Wyciskanie sztangi na ławce',
  muscles: [MuscleGroup.chest],
  category: ExerciseCategory.compound,
  pattern: 'push_horizontal',
  equipment: ExerciseEquipment.barbell,
);
const _dbBench = Exercise(
  id: 'db',
  name: 'Wyciskanie hantli na ławce',
  muscles: [MuscleGroup.chest],
  category: ExerciseCategory.compound,
  pattern: 'push_horizontal',
  equipment: ExerciseEquipment.dumbbell,
);
const _squat = Exercise(
  id: 'squat',
  name: 'Przysiad',
  muscles: [MuscleGroup.quads],
  category: ExerciseCategory.compound,
  pattern: 'squat',
);

void main() {
  Future<Future<Exercise?>> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 2, 1400 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('trening')),
      ),
    );
    final result = navigatorKey.currentState!.push<Exercise>(
      MaterialPageRoute(
        builder: (_) => const SwapExerciseScreen(
          replacing: TrainingSessionExerciseSummary(
            exerciseId: 'bench',
            name: 'Wyciskanie sztangi na ławce',
            tracking: ExerciseTracking.weightReps,
          ),
          exercises: [_bench, _dbBench, _squat],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('podobne na górze, zastępowane ćwiczenie pominięte, stuknięcie '
      'zwraca zamiennik', (tester) async {
    final result = await pump(tester);
    expect(find.text('zamiast: Wyciskanie sztangi na ławce'), findsOneWidget);
    expect(find.text('PODOBNE'), findsOneWidget);
    expect(find.text('POZOSTAŁE'), findsOneWidget);
    expect(find.text('Wyciskanie sztangi na ławce'), findsNothing);

    await tester.tap(find.text('Wyciskanie hantli na ławce'));
    await tester.pumpAndSettle();
    expect((await result)!.id, 'db');
  });

  testWidgets('szukanie filtruje całą bibliotekę', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'przysiad');
    await tester.pumpAndSettle();
    expect(find.text('Przysiad'), findsOneWidget);
    expect(find.text('Wyciskanie hantli na ławce'), findsNothing);
    expect(find.text('PODOBNE'), findsNothing);
  });
}
