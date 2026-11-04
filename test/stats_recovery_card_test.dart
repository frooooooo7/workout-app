import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_recovery_card.dart';

/// Środa 16 września 2026.
final _today = DateTime(2026, 9, 16);

MuscleRecoveryStat _stat(MuscleGroup muscle, int daysSince, double perWeek) =>
    MuscleRecoveryStat(
      muscle: muscle,
      lastTrainedAt: _today.subtract(Duration(days: daysSince)),
      daysSince: daysSince,
      setsPerWeek: perWeek,
    );

/// Sześć partii, po jednej na każdy próg statusu i wariant tekstu.
List<MuscleRecoveryStat> _sixRows() => [
  _stat(MuscleGroup.legs, 0, 12),
  _stat(MuscleGroup.back, 1, 8.5),
  _stat(MuscleGroup.chest, 2, 10),
  _stat(MuscleGroup.biceps, 6, 3),
  _stat(MuscleGroup.triceps, 7, 0),
  _stat(MuscleGroup.abs, 30, 1),
];

Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: card,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 800));
}

void main() {
  group('StatsRecoveryCard', () {
    testWidgets('groups muscles by days since last workout', (tester) async {
      await _pump(tester, StatsRecoveryCard(recovery: _sixRows()));

      expect(find.text('Regeneracja'), findsOneWidget);
      expect(find.text('z całej historii'), findsOneWidget);
      // 0–1 dni odpoczywają, 2–6 gotowe, 7+ dawno bez treningu.
      expect(find.text('Odpoczywają'), findsOneWidget);
      expect(find.text('Gotowe do treningu'), findsOneWidget);
      expect(find.text('Dawno bez treningu'), findsOneWidget);

      expect(find.text('Nogi · dziś'), findsOneWidget);
      expect(find.text('Plecy · wczoraj'), findsOneWidget);
      expect(find.text('Klatka · 2 dni'), findsOneWidget);
      expect(find.text('Biceps · 6 dni'), findsOneWidget);
      expect(find.text('Triceps · 7 dni'), findsOneWidget);
      expect(find.text('Brzuch · 4 tyg.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long breaks use weeks, months and years', (tester) async {
      await _pump(
        tester,
        StatsRecoveryCard(
          recovery: [
            _stat(MuscleGroup.legs, 62, 0),
            _stat(MuscleGroup.back, 150, 0),
            _stat(MuscleGroup.chest, 400, 0),
            _stat(MuscleGroup.biceps, 14, 0),
          ],
        ),
      );
      expect(find.text('Nogi · 2 mies.'), findsOneWidget);
      expect(find.text('Plecy · 5 mies.'), findsOneWidget);
      expect(find.text('Klatka · 1 r.'), findsOneWidget);
      expect(find.text('Biceps · 2 tyg.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides groups that have no muscles', (tester) async {
      await _pump(
        tester,
        StatsRecoveryCard(recovery: [_stat(MuscleGroup.legs, 3, 0)]),
      );

      expect(find.text('Gotowe do treningu'), findsOneWidget);
      expect(find.text('Odpoczywają'), findsNothing);
      expect(find.text('Dawno bez treningu'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty list shows a note', (tester) async {
      await _pump(tester, const StatsRecoveryCard(recovery: []));

      expect(find.text('Regeneracja'), findsOneWidget);
      expect(
        find.text('Brak danych o partiach — przypisz mięśnie do ćwiczeń.'),
        findsOneWidget,
      );
      expect(find.text('Gotowe do treningu'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each chip is one semantics node', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        StatsRecoveryCard(
          recovery: [
            _stat(MuscleGroup.legs, 1, 8.5),
            _stat(MuscleGroup.back, 9, 0),
          ],
        ),
      );

      expect(
        find.bySemanticsLabel('Nogi, odpoczywają, ostatnio wczoraj'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Plecy, dawno bez treningu, ostatnio 9 dni'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('does not overflow at 360 px with large text', (tester) async {
      await _pump(
        tester,
        StatsRecoveryCard(
          recovery: [
            _stat(MuscleGroup.frontDelts, 0, 20.5),
            _stat(MuscleGroup.hamstrings, 8, 123.4),
            _stat(MuscleGroup.lowerBack, 500, 0.3),
            _stat(MuscleGroup.rearDelts, 3, 9.5),
          ],
        ),
        textScale: 2.5,
      );

      expect(find.byType(StatsRecoveryCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
