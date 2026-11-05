import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/units/weight_unit.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/services/workout_comparison.dart';
import 'package:gym/features/training/presentation/widgets/workout_summary/workout_comparison_card.dart';

TrainingSessionSet _set(String weight, String reps) =>
    TrainingSessionSet(actualWeight: weight, actualReps: reps, completed: true);

TrainingSessionExercise _exercise(String name, List<TrainingSessionSet> sets) =>
    TrainingSessionExercise(
      exerciseId: name.toLowerCase(),
      exerciseName: name,
      exerciseMuscles: const ['chest'],
      exerciseCategory: 'compound',
      sets: sets,
    );

TrainingSession _session(
  DateTime startedAt,
  List<TrainingSessionExercise> exercises, {
  String? planLocalId = 'plan-1',
  int minutes = 60,
}) => TrainingSession(
  id: startedAt.toIso8601String(),
  planName: planLocalId == null ? TrainingSession.defaultCustomName : 'Push A',
  planLocalId: planLocalId,
  status: TrainingSessionStatus.completed,
  startedAt: startedAt,
  finishedAt: startedAt.add(Duration(minutes: minutes)),
  exercises: exercises,
);

final _monday = DateTime.utc(2026, 11, 2, 17);
final _thursday = DateTime.utc(2026, 11, 5, 17);

Future<void> _pump(
  WidgetTester tester,
  WorkoutComparison comparison, {
  void Function(String)? onOpenPrevious,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: WorkoutComparisonCard(
            comparison: comparison,
            onOpenPrevious: onOpenPrevious,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => WeightUnits.notifier.value = WeightUnit.kg);

  group('plan comparison', () {
    late TrainingSession previous;
    late TrainingSession today;

    setUp(() {
      previous = _session(_monday, [
        _exercise('Wyciskanie sztangi', [
          _set('80', '8'),
          _set('80', '8'),
          _set('80', '7'),
        ]),
        _exercise('Wyciskanie hantli', [_set('30', '9')]),
        _exercise('Żołnierskie', [_set('50', '6')]),
        _exercise('Pompki', [_set('', '14')]),
      ], minutes: 62);
      today = _session(_thursday, [
        _exercise('Wyciskanie sztangi', [
          _set('82,5', '8'),
          _set('82,5', '8'),
          _set('82,5', '7'),
        ]),
        _exercise('Wyciskanie hantli', [_set('30', '10')]),
        _exercise('Żołnierskie', [_set('50', '6')]),
        _exercise('Pompki', [_set('', '12')]),
        _exercise('Prostowanie ramion', [_set('25', '12')]),
      ], minutes: 58);
    });

    testWidgets('shows verdict, totals and per-exercise results', (
      tester,
    ) async {
      await _pump(tester, compareWithPrevious(today, [previous, today])!);

      expect(find.text('Porównanie z poprzednim'), findsOneWidget);
      expect(find.text('pon, 2 lis'), findsOneWidget);
      expect(find.text('Progres w 2 z 4 ćwiczeń'), findsOneWidget);
      expect(find.text('1 bez zmian · 1 słabiej · 1 nowe'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('workout-comparison-bar')),
        findsOneWidget,
      );

      // Sumy: objętość rośnie, serie +1 (nowe ćwiczenie), czas −4 min.
      final volume = find.byKey(const ValueKey('comparison-volume'));
      expect(
        find.descendant(of: volume, matching: find.textContaining('było')),
        findsOneWidget,
      );
      final time = find.byKey(const ValueKey('comparison-time'));
      expect(
        find.descendant(of: time, matching: find.text('−4 min')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: time, matching: find.text('było 1:02:00')),
        findsOneWidget,
      );

      expect(find.text('2,5 kg'), findsOneWidget);
      expect(find.text('1 powt.'), findsOneWidget);
      expect(find.text('2 powt.'), findsOneWidget);
      expect(find.text('bez zmian'), findsOneWidget);
      expect(find.text('Nowe'), findsOneWidget);
      expect(find.textContaining('pierwszy raz'), findsOneWidget);
    });

    testWidgets('tap on an exercise expands set by set', (tester) async {
      await _pump(tester, compareWithPrevious(today, [previous])!);

      final row = find.byKey(
        const ValueKey('comparison-exercise-name:wyciskanie sztangi'),
      );
      expect(
        find.byKey(const ValueKey('comparison-sets-name:wyciskanie sztangi')),
        findsNothing,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();

      final sets = find.byKey(
        const ValueKey('comparison-sets-name:wyciskanie sztangi'),
      );
      expect(sets, findsOneWidget);
      expect(
        find.descendant(of: sets, matching: find.text('PON, 2 LIS')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sets, matching: find.text('80 × 7')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sets, matching: find.text('82,5 × 7')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sets, matching: find.text('Objętość ćwiczenia')),
        findsOneWidget,
      );

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(sets, findsNothing);
    });

    testWidgets('new exercises cannot be expanded', (tester) async {
      await _pump(tester, compareWithPrevious(today, [previous])!);
      await tester.tap(
        find.byKey(
          const ValueKey('comparison-exercise-name:prostowanie ramion'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('comparison-sets-name:prostowanie ramion')),
        findsNothing,
      );
    });

    testWidgets('date link opens the previous workout', (tester) async {
      String? opened;
      await _pump(
        tester,
        compareWithPrevious(today, [previous])!,
        onOpenPrevious: (id) => opened = id,
      );

      await tester.tap(
        find.byKey(const ValueKey('workout-comparison-previous-link')),
      );
      expect(opened, previous.id);
    });

    testWidgets('weight differences follow the weight unit', (tester) async {
      WeightUnits.notifier.value = WeightUnit.lb;
      await _pump(tester, compareWithPrevious(today, [previous])!);

      // 2,5 kg ≈ 5,5 lb.
      expect(find.text('5,5 lb'), findsOneWidget);
      expect(find.text('2,5 kg'), findsNothing);
    });
  });

  testWidgets('weaker day keeps a neutral verdict and red drops', (
    tester,
  ) async {
    final previous = _session(_monday, [
      _exercise('Wyciskanie sztangi', [_set('80', '8')]),
      _exercise('Wyciskanie hantli', [_set('30', '10')]),
      _exercise('Żołnierskie', [_set('50', '6')]),
    ]);
    final today = _session(_thursday, [
      _exercise('Wyciskanie sztangi', [_set('80', '6')]),
      _exercise('Wyciskanie hantli', [_set('27,5', '10')]),
      _exercise('Żołnierskie', [_set('50', '6')]),
    ], minutes: 66);

    await _pump(tester, compareWithPrevious(today, [previous])!);

    expect(find.text('Słabiej w 2 z 3 ćwiczeń'), findsOneWidget);
    expect(find.text('1 bez zmian'), findsOneWidget);
    expect(find.text('2 powt.'), findsOneWidget);
    expect(find.text('2,5 kg'), findsOneWidget);
    final time = find.byKey(const ValueKey('comparison-time'));
    expect(
      find.descendant(of: time, matching: find.text('+6 min')),
      findsOneWidget,
    );
  });

  testWidgets('first workout of a plan is a single line instead of a card', (
    tester,
  ) async {
    final today = _session(_thursday, [
      _exercise('Wyciskanie sztangi', [_set('80', '8')]),
    ]);
    await _pump(tester, compareWithPrevious(today, const [])!);

    expect(find.text('Pierwszy trening „Push A”'), findsOneWidget);
    expect(find.byKey(const ValueKey('workout-comparison-card')), findsNothing);
  });

  testWidgets('free workout lists last performances with dates, no totals', (
    tester,
  ) async {
    final previous = _session(_monday, [
      _exercise('Wiosłowanie', [_set('70', '8')]),
    ], planLocalId: null);
    final today = _session(_thursday, [
      _exercise('Wiosłowanie', [_set('72,5', '8')]),
    ], planLocalId: null);

    await _pump(tester, compareWithPrevious(today, [previous])!);

    expect(find.text('ostatnie wykonania'), findsOneWidget);
    expect(find.text('Progres w 1 z 1 ćwiczenia'), findsOneWidget);
    expect(find.textContaining('2 lis'), findsOneWidget);
    expect(find.byKey(const ValueKey('comparison-volume')), findsNothing);
    expect(
      find.byKey(const ValueKey('workout-comparison-previous-link')),
      findsNothing,
    );
  });
}
