import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/muscle_role.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';
import 'package:gym/features/training/presentation/widgets/session_details/session_muscle_map.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_muscles_card.dart';

const _sources = [
  MuscleSource(
    exerciseName: 'Wyciskanie sztangi leżąc na ławce płaskiej',
    sets: 12,
    targetSets: 12,
    volumeKg: 148200,
  ),
  MuscleSource(
    exerciseName: 'Rozpiętki',
    sets: 14,
    targetSets: 3,
    volumeKg: 8200,
  ),
];

const _distribution = MuscleDistribution(
  taggedSets: 14,
  muscles: [
    MuscleStat(
      muscle: MuscleGroup.chest,
      sets: 14,
      volumeKg: 0,
      share: 1,
      intensity: 1,
      role: MuscleRole.primary,
      targetSets: 12,
      sources: _sources,
    ),
    MuscleStat(
      muscle: MuscleGroup.triceps,
      sets: 5,
      volumeKg: 0,
      share: 0.3,
      intensity: 0.3,
      role: MuscleRole.secondary,
    ),
  ],
  regions: [RegionStat(region: MuscleRegion.chest, sets: 14, share: 1)],
  neglected: [],
  bodyRoles: {
    MuscleGroup.chest: MuscleRole.primary,
    MuscleGroup.triceps: MuscleRole.secondary,
  },
);

TrainingSessionDetail _detail() {
  final metrics = TrainingSetMetrics(weightKg: 100, reps: 5);
  var i = 0;
  TrainingExerciseSetDetail set() => TrainingExerciseSetDetail(
    setIndex: ++i,
    planned: metrics,
    actual: metrics,
    completed: true,
  );
  return TrainingSessionDetail(
    id: 's1',
    startedAt: DateTime.utc(2026, 6, 30, 17),
    endedAt: DateTime.utc(2026, 6, 30, 18),
    durationSec: 3600,
    status: TrainingSessionStatus.completed,
    plan: const TrainingPlanSummary(id: 'p1', name: 'Push'),
    note: null,
    exercises: [
      TrainingExerciseDetail(
        exerciseId: 'e1',
        exerciseName: 'Wyciskanie sztangi leżąc na ławce płaskiej',
        muscles: const [MuscleGroup.chest, MuscleGroup.triceps],
        sets: [for (var k = 0; k < 12; k++) set()],
      ),
    ],
    updatedAt: DateTime.utc(2026, 6, 30, 18),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required double width,
  required double textScale,
}) async {
  tester.view.physicalSize = Size(width, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.dark(),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: c!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 800));
}

void main() {
  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets('stats card does not overflow at $width px x$scale', (
        tester,
      ) async {
        await _pump(
          tester,
          const StatsMuscleRankingCard(muscles: _distribution),
          width: width,
          textScale: scale,
        );
        await tester.tap(find.text('Klatka').last);
        await tester.pump(const Duration(milliseconds: 800));

        expect(find.text('Rozpiętki'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('session map does not overflow at $width px x$scale', (
        tester,
      ) async {
        await _pump(
          tester,
          SessionMuscleMap(detail: _detail()),
          width: width,
          textScale: scale,
        );
        await tester.tap(find.text('Klatka piersiowa'));
        await tester.pump(const Duration(milliseconds: 800));

        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('ranking row is a tappable button and its sources stay readable '
      'for screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const StatsMuscleRankingCard(muscles: _distribution),
      width: 360,
      textScale: 1,
    );

    final row = find.bySemanticsLabel(RegExp('^Klatka.*serii.*główne'));
    expect(row, findsOneWidget);
    expect(
      tester.getSemantics(row),
      matchesSemantics(
        isButton: true,
        hasTapAction: true,
        hasExpandedState: true,
        label: tester.getSemantics(row).label,
      ),
    );

    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.bySemanticsLabel('Rozpiętki'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('session chip exposes a tap action to screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      SessionMuscleMap(detail: _detail()),
      width: 400,
      textScale: 1,
    );

    final node = tester.getSemantics(
      find.bySemanticsLabel(RegExp('^Klatka piersiowa, główny')),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });
}
