import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/profile/domain/services/profile_week_calculator.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';
import 'package:gym/features/training/domain/services/stats/muscle_distribution_calculator.dart';
import 'package:gym/features/training/domain/services/stats/training_stats_calculator.dart';
import 'package:gym/features/training/domain/services/stats/weekly_goal_calculator.dart';
import 'package:gym/features/training/presentation/widgets/stats/overview/stats_period_summary_card.dart';

TrainingSession _session(DateTime start, {List<String> muscles = const []}) =>
    TrainingSession(
      planName: 'Push',
      status: TrainingSessionStatus.completed,
      startedAt: start,
      finishedAt: start.add(const Duration(minutes: 50)),
      exercises: [
        TrainingSessionExercise(
          exerciseId: 'e',
          exerciseName: 'Ćwiczenie',
          exerciseMuscles: muscles,
          exerciseCategory: 'compound',
          sets: [
            TrainingSessionSet(
              actualWeight: '50',
              actualReps: '10',
              completed: true,
            ),
          ],
        ),
      ],
    );

/// Środa 16 września 2026; pierwszy trening 26 tygodni wcześniej.
final _now = DateTime(2026, 9, 16, 12);

/// Dwa treningi tygodniowo przez [weeks] ostatnich tygodni (z bieżącym).
List<TrainingSession> _twiceAWeek(int weeks) => [
  for (var w = 0; w < weeks; w++) ...[
    _session(DateTime(2026, 9, 14 - 7 * w, 18)),
    _session(DateTime(2026, 9, 15 - 7 * w, 18)),
  ],
];

void main() {
  group('weekly goal history', () {
    test('allWeeks spans from the first workout week to the current one', () {
      final goal = WeeklyGoalCalculator.compute(
        _twiceAWeek(20),
        today: _now,
        goal: 2,
      )!;
      expect(goal.weeks, hasLength(WeeklyGoalCalculator.weeksShown));
      expect(goal.allWeeks, hasLength(20));
      expect(goal.allWeeks.last.start, goal.weeks.last.start);
      expect(goal.allWeeks.every((w) => w.workouts == 2), isTrue);
    });

    test('allWeeks falls back to the shown weeks when not provided', () {
      final goal = WeeklyGoalProgress(
        goal: 3,
        workoutsThisWeek: 1,
        weeks: [GoalWeek(start: DateTime(2026, 9, 14), workouts: 1)],
        streakWeeks: 0,
        bestStreakWeeks: 0,
        daysLeft: 4,
      );
      expect(goal.allWeeks, goal.weeks);
    });
  });

  group('period card goal weeks', () {
    Future<void> pump(WidgetTester tester, StatsRange range) async {
      tester.view.physicalSize = const Size(412, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final snapshot = TrainingStatsCalculator.compute(
        _twiceAWeek(20),
        range: range,
        now: _now,
        weeklyGoal: 2,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatsPeriodSummaryCard(
                snapshot: snapshot,
                onOpenTrend: () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('a quarter counts every week of the range, not eight', (
      tester,
    ) async {
      await pump(tester, StatsRange.quarter);
      // 3 miesiące to 13–14 tygodni; bieżący (wykonany) liczy się do celu.
      final pill = find.textContaining('cel w ');
      expect(pill, findsOneWidget);
      final text = (tester.widget(pill) as Text).data!;
      final total = int.parse(
        RegExp(r'z (\d+) tyg').firstMatch(text)!.group(1)!,
      );
      expect(total, greaterThan(WeeklyGoalCalculator.weeksShown));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the whole history counts all 20 weeks', (tester) async {
      await pump(tester, StatsRange.all);
      expect(find.text('cel w 20 z 20 tyg.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('profile streak', () {
    test('with a goal only weeks that met it count', () {
      // Bieżący tydzień: 2 treningi, poprzedni: 1 (poniżej celu 2).
      final summary = ProfileWeekCalculator.summarize(
        [
          _session(DateTime(2026, 9, 14, 18)),
          _session(DateTime(2026, 9, 15, 18)),
          _session(DateTime(2026, 9, 8, 18)),
          _session(DateTime(2026, 9, 1, 18)),
          _session(DateTime(2026, 9, 2, 18)),
        ],
        now: _now,
        goal: 2,
      );
      expect(summary.streakWeeks, 1);
      expect(summary.streakByGoal, isTrue);
    });

    test('an unmet current week does not break the streak yet', () {
      final summary = ProfileWeekCalculator.summarize(
        [
          _session(DateTime(2026, 9, 14, 18)),
          _session(DateTime(2026, 9, 7, 18)),
          _session(DateTime(2026, 9, 8, 18)),
          _session(DateTime(2026, 8, 31, 18)),
          _session(DateTime(2026, 9, 1, 18)),
        ],
        now: _now,
        goal: 2,
      );
      expect(summary.streakWeeks, 2);
    });

    test('without a goal any workout keeps the streak', () {
      final summary = ProfileWeekCalculator.summarize([
        _session(DateTime(2026, 9, 14, 18)),
        _session(DateTime(2026, 9, 8, 18)),
      ], now: _now);
      expect(summary.streakWeeks, 2);
      expect(summary.streakByGoal, isFalse);
    });
  });

  group('region bars', () {
    test('a region counts the trained muscle groups it sums', () {
      final result = MuscleDistributionCalculator.compute([
        _session(DateTime(2026, 9, 14, 18), muscles: const ['biceps']),
        _session(DateTime(2026, 9, 15, 18), muscles: const ['triceps']),
        _session(DateTime(2026, 9, 16, 9), muscles: const ['chest']),
      ]);
      final arms = result.regions.firstWhere(
        (r) => r.region == MuscleRegion.arms,
      );
      final chest = result.regions.firstWhere(
        (r) => r.region == MuscleRegion.chest,
      );
      expect(arms.muscleCount, 2);
      expect(chest.muscleCount, 1);
    });
  });
}
