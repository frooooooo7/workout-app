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

/// Sześć wierszy, po jednym na każdy próg statusu i wariant tekstu.
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

/// Tekst z wieloma spanami (`Text.rich`) — zwykłe `find.text` go nie widzi.
Finder _rich(String text) => find.text(text, findRichText: true);

void main() {
  group('StatsRecoveryCard', () {
    testWidgets('shows status pills by days since last workout', (
      tester,
    ) async {
      await _pump(tester, StatsRecoveryCard(recovery: _sixRows()));

      expect(find.text('Nogi'), findsOneWidget);
      expect(find.text('Plecy'), findsOneWidget);
      expect(find.text('Klatka'), findsOneWidget);
      expect(find.text('Biceps'), findsOneWidget);
      expect(find.text('Triceps'), findsOneWidget);
      expect(find.text('Brzuch'), findsOneWidget);

      // Tytuł karty też brzmi „Regeneracja”: 0–1 dni to dwie pigułki.
      expect(find.text('Regeneracja'), findsNWidgets(1 + 2));
      // 2–6 dni.
      expect(find.text('Gotowe'), findsNWidgets(2));
      // 7 dni i więcej.
      expect(find.text('Dawno bez treningu'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('relative text uses Polish plurals', (tester) async {
      await _pump(tester, StatsRecoveryCard(recovery: _sixRows()));

      expect(find.text('dziś'), findsOneWidget);
      expect(find.text('wczoraj'), findsOneWidget);
      expect(find.text('2 dni temu'), findsOneWidget);
      expect(find.text('6 dni temu'), findsOneWidget);
      expect(find.text('7 dni temu'), findsOneWidget);
      expect(find.text('30 dni temu'), findsOneWidget);

      // Dłuższe przerwy: miesiące i lata z poprawną odmianą.
      await _pump(
        tester,
        StatsRecoveryCard(
          recovery: [
            _stat(MuscleGroup.legs, 62, 0),
            _stat(MuscleGroup.back, 150, 0),
            _stat(MuscleGroup.chest, 400, 0),
            _stat(MuscleGroup.biceps, 800, 0),
            _stat(MuscleGroup.triceps, 2000, 0),
          ],
        ),
      );
      expect(find.text('2 miesiące temu'), findsOneWidget);
      expect(find.text('5 miesięcy temu'), findsOneWidget);
      expect(find.text('rok temu'), findsOneWidget);
      expect(find.text('2 lata temu'), findsOneWidget);
      expect(find.text('5 lat temu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('weekly volume label formats numbers and plurals', (
      tester,
    ) async {
      await _pump(
        tester,
        StatsRecoveryCard(
          recovery: [
            _stat(MuscleGroup.legs, 0, 12),
            _stat(MuscleGroup.back, 1, 8.5),
            _stat(MuscleGroup.chest, 2, 1),
            _stat(MuscleGroup.biceps, 3, 3),
            _stat(MuscleGroup.triceps, 4, 0),
          ],
        ),
      );

      expect(_rich('12 serii / tydz.'), findsOneWidget);
      expect(_rich('8,5 serii / tydz.'), findsOneWidget);
      expect(_rich('1 seria / tydz.'), findsOneWidget);
      expect(_rich('3 serie / tydz.'), findsOneWidget);
      expect(_rich('0 serii / tydz.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('volume bar fills to sets per week out of 20, clamped', (
      tester,
    ) async {
      await _pump(
        tester,
        StatsRecoveryCard(
          recovery: [
            _stat(MuscleGroup.legs, 0, 12),
            _stat(MuscleGroup.back, 1, 8.5),
            _stat(MuscleGroup.chest, 2, 30),
            _stat(MuscleGroup.biceps, 3, 0),
          ],
        ),
      );

      final values = [
        for (final bar in tester.widgetList<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        ))
          bar.value,
      ];
      expect(values, [0.6, 0.425, 1.0, 0.0]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('caption gives the weekly volume guideline', (tester) async {
      await _pump(tester, StatsRecoveryCard(recovery: _sixRows()));

      expect(
        find.text(
          'Orientacyjnie 10–20 serii tygodniowo na partię wystarcza '
          'większości osób do przyrostu siły i masy.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows six rows and a show-all toggle for more', (
      tester,
    ) async {
      await _pump(
        tester,
        StatsRecoveryCard(
          recovery: [
            ..._sixRows(),
            _stat(MuscleGroup.glutes, 40, 0),
            _stat(MuscleGroup.forearms, 50, 0),
          ],
        ),
      );

      expect(find.text('Pośladki'), findsNothing);
      expect(find.text('Przedramiona'), findsNothing);
      expect(find.text('Zwiń'), findsNothing);

      await tester.ensureVisible(find.text('Pokaż wszystkie'));
      await tester.tap(find.text('Pokaż wszystkie'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Pośladki'), findsOneWidget);
      expect(find.text('Przedramiona'), findsOneWidget);
      expect(find.text('40 dni temu'), findsOneWidget);
      expect(find.text('Pokaż wszystkie'), findsNothing);

      await tester.ensureVisible(find.text('Zwiń'));
      await tester.tap(find.text('Zwiń'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Pośladki'), findsNothing);
      expect(find.text('Pokaż wszystkie'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no toggle up to six rows', (tester) async {
      await _pump(tester, StatsRecoveryCard(recovery: _sixRows()));

      expect(find.text('Pokaż wszystkie'), findsNothing);
      expect(find.text('Zwiń'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty list shows a note', (tester) async {
      await _pump(tester, const StatsRecoveryCard(recovery: []));

      expect(find.text('Regeneracja'), findsOneWidget); // tylko tytuł
      expect(
        find.text('Brak danych o partiach — przypisz mięśnie do ćwiczeń.'),
        findsOneWidget,
      );
      expect(find.textContaining('Orientacyjnie'), findsNothing);
      expect(find.text('Pokaż wszystkie'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('each row is one semantics node', (tester) async {
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
        find.bySemanticsLabel(
          'Nogi: ostatnio wczoraj, regeneracja, 8,5 serii tygodniowo',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Plecy: ostatnio 9 dni temu, dawno bez treningu, '
          '0 serii tygodniowo',
        ),
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
        // Bardzo duża czcionka: pigułki i podpisy muszą się skracać,
        // a nie wypychać wiersza.
        textScale: 2.5,
      );

      expect(find.byType(StatsRecoveryCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
