import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';
import 'package:gym/features/training/domain/services/stats/muscle_distribution_calculator.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_format.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_goal_card.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_muscles_card.dart';
import 'package:gym/features/training/presentation/widgets/stats/stats_rep_ranges_card.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  group('roundedPercents', () {
    test('parts that share 100 always add up to it', () {
      expect(roundedPercents([1 / 3, 1 / 3, 1 / 3]), [34, 33, 33]);
      expect(
        roundedPercents(List.filled(6, 1 / 6)).fold<int>(0, (a, b) => a + b),
        100,
      );
      expect(roundedPercents([0.5, 0.5]), [50, 50]);
      expect(roundedPercents([1]), [100]);
    });

    test('a share under half a percent stays visible as "<1%"', () {
      final p = roundedPercents([0.003, 0.997]);
      expect(p.fold<int>(0, (a, b) => a + b), 100);
      expect(formatStatsPercent(0, nonZero: true), '<1%');
      expect(formatStatsPercent(0, nonZero: false), '0%');
      expect(formatStatsPercent(34, nonZero: true), '34%');
    });

    test('a total other than 1 falls back to plain rounding', () {
      expect(roundedPercents([0.2, 0.3]), [20, 30]);
      expect(roundedPercents(const []), isEmpty);
      expect(roundedPercents([0, 0]), [0, 0]);
    });
  });

  group('muscles card', () {
    MuscleStat unit(MuscleGroup g, double share) => MuscleStat(
      muscle: g,
      sets: share * 60,
      volumeKg: 0,
      share: share,
      intensity: 1,
    );

    final window = StatsWindow(
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 9, 29), // 28 dni = 4 tygodnie
      bucket: StatsBucket.day,
    );

    testWidgets('region bars show weekly sets against the 10–20 band', (
      tester,
    ) async {
      await _pump(
        tester,
        StatsRegionBarsCard(
          muscles: MuscleDistribution(
            taggedSets: 80,
            muscles: [
              unit(MuscleGroup.chest, 0.5),
              unit(MuscleGroup.legs, 0.5),
            ],
            regions: const [
              RegionStat(region: MuscleRegion.chest, sets: 60, share: 0.5),
              RegionStat(region: MuscleRegion.legs, sets: 20, share: 0.5),
            ],
            neglected: const [MuscleGroup.abs],
          ),
          window: window,
          rangeLabel: '30 dni',
        ),
      );

      // 60 serii w 4 tygodniach to 15 / tydz., 20 serii to 5.
      expect(find.text('15 / tydz.', findRichText: true), findsOneWidget);
      expect(find.text('5 / tydz.', findRichText: true), findsOneWidget);
      expect(find.textContaining('10–20 serii / tydz.'), findsOneWidget);
      expect(find.text('średnio z 30 dni'), findsOneWidget);
      // Brzuch (partia bez serii) dostaje wiersz z zerem.
      expect(find.text('Brzuch'), findsOneWidget);
      expect(find.text('0 / tydz.', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a window shorter than a week counts as one week', (
      tester,
    ) async {
      await _pump(
        tester,
        StatsRegionBarsCard(
          muscles: MuscleDistribution(
            taggedSets: 12,
            muscles: [unit(MuscleGroup.chest, 1)],
            regions: const [
              RegionStat(region: MuscleRegion.chest, sets: 12, share: 1),
            ],
            neglected: const [],
          ),
          window: StatsWindow(
            start: DateTime(2026, 9, 1),
            end: DateTime(2026, 9, 4),
            bucket: StatsBucket.day,
          ),
          rangeLabel: 'wybranego okresu',
        ),
      );
      // 12 serii w 3 dni nie jest rekordowym tygodniem: liczymy jak tydzień.
      expect(find.text('12 / tydz.', findRichText: true), findsOneWidget);
    });

    testWidgets('a big weekly total at a large font stays inside the row', (
      tester,
    ) async {
      await _pump(
        tester,
        StatsRegionBarsCard(
          muscles: MuscleDistribution(
            taggedSets: 3120,
            muscles: [unit(MuscleGroup.chest, 1)],
            regions: const [
              RegionStat(region: MuscleRegion.chest, sets: 3120, share: 1),
            ],
            neglected: const [],
          ),
          window: window,
          rangeLabel: '30 dni',
        ),
        textScale: 1.5,
      );
      expect(tester.takeException(), isNull);
    });

    test('the calculator counts completed sets of tagged exercises only', () {
      TrainingSessionExercise ex(List<String> muscles, int sets) =>
          TrainingSessionExercise(
            exerciseId: '',
            exerciseName: muscles.join(),
            exerciseMuscles: muscles,
            exerciseCategory: 'compound',
            sets: [
              for (var i = 0; i < sets; i++)
                TrainingSessionSet(
                  actualWeight: '50',
                  actualReps: '8',
                  completed: true,
                ),
              TrainingSessionSet(actualReps: '8'), // nieukończona
            ],
          );
      final result = MuscleDistributionCalculator.compute([
        TrainingSession(
          planName: 'P',
          status: TrainingSessionStatus.completed,
          startedAt: DateTime.utc(2026, 9, 14),
          finishedAt: DateTime.utc(2026, 9, 14, 1),
          exercises: [
            ex(['chest', 'triceps', 'shoulders'], 3),
            ex(const [], 4), // bez tagów — poza rankingiem
          ],
        ),
      ]);
      expect(result.taggedSets, 3);
    });
  });

  group('rep ranges card', () {
    testWidgets('"100%" keeps its percent sign at a large font', (
      tester,
    ) async {
      await _pump(
        tester,
        const StatsRepRangesCard(ranges: RepRangeDistribution(hypertrophy: 12)),
        textScale: 1.5,
      );
      expect(find.text('100%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('goal card', () {
    WeeklyGoalProgress goal({
      required int goal,
      int done = 0,
      List<int> history = const [2, 1],
    }) => WeeklyGoalProgress(
      goal: goal,
      workoutsThisWeek: done,
      weeks: [
        for (final (i, w) in [...history, done].indexed)
          GoalWeek(start: DateTime(2026, 8, 3 + 7 * i), workouts: w),
      ],
      streakWeeks: 0,
      bestStreakWeeks: 0,
      daysLeft: 4,
    );

    testWidgets('a goal of one reads "z 1 treningu" for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, StatsGoalCard(goal: goal(goal: 1)));
      expect(find.bySemanticsLabel('0 z 1 treningu'), findsOneWidget);
      await _pump(tester, StatsGoalCard(goal: goal(goal: 4, done: 2)));
      expect(find.bySemanticsLabel('2 z 4 treningów'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the running week is not counted as a miss', (tester) async {
      // Cel 2: poprzednie tygodnie 2 i 1 → jeden z dwóch; bieżący (0) pomijamy.
      await _pump(tester, StatsGoalCard(goal: goal(goal: 2)));
      expect(find.text('Wykonany w 1 z 2 ostatnich tygodni'), findsOneWidget);

      // Po wykonaniu celu bieżący tydzień dołącza do podsumowania.
      await _pump(tester, StatsGoalCard(goal: goal(goal: 2, done: 2)));
      expect(find.text('Wykonany w 2 z 3 ostatnich tygodni'), findsOneWidget);
    });
  });
}
