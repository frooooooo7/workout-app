import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/services/history_feed_builder.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_feed_list.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_session_card.dart';

HistoryFeedEntry _entry(String id, DateTime local, {int records = 0}) =>
    HistoryFeedEntry(
      item: TrainingSessionListItem(
        id: id,
        startedAt: local.toUtc(),
        endedAt: null,
        durationSec: 3600,
        status: TrainingSessionStatus.completed,
        plan: const TrainingPlanSummary(id: 'p', name: 'Push'),
        exercisesCount: 4,
        completedSetsCount: 12,
        hasNote: false,
        updatedAt: local.toUtc(),
        totalVolumeKg: 5000,
      ),
      recordsCount: records,
    );

void main() {
  group('groupHistoryFeed', () {
    test('splits months, weeks and days, newest first', () {
      final sections = groupHistoryFeed([
        _entry('a', DateTime(2026, 11, 3, 18)),
        _entry('b', DateTime(2026, 11, 3, 8)),
        _entry('c', DateTime(2026, 11, 1, 18)),
        _entry('d', DateTime(2026, 10, 28, 18)),
      ]);

      expect(sections.map((s) => s.month), [
        DateTime(2026, 11),
        DateTime(2026, 10),
      ]);
      final november = sections.first.rows;
      // Tydzień 2–8 lis, dzień 3 (dwa treningi), potem tydzień 26 paź–1 lis
      // z dniem 1.
      expect(november[0], isA<HistoryWeekRow>());
      expect((november[1] as HistoryDayRow).entries.map((e) => e.item.id), [
        'a',
        'b',
      ]);
      expect(november[2], isA<HistoryWeekRow>());
      expect((november[3] as HistoryDayRow).day, DateTime(2026, 11, 1));
    });

    test('a week cut by a month boundary shows its goal only once', () {
      final sections = groupHistoryFeed([
        _entry('a', DateTime(2026, 11, 1, 18)),
        _entry('b', DateTime(2026, 10, 30, 18)),
      ]);

      final novemberWeek = sections[0].rows.first as HistoryWeekRow;
      final octoberWeek = sections[1].rows.first as HistoryWeekRow;
      expect(novemberWeek.weekStart, octoberWeek.weekStart);
      expect(novemberWeek.showGoal, isTrue);
      expect(octoberWeek.showGoal, isFalse);
    });

    test('counts workouts per week', () {
      final counts = workoutsPerWeek([
        _entry('a', DateTime(2026, 11, 3, 18)),
        _entry('b', DateTime(2026, 11, 2, 18)),
        _entry('c', DateTime(2026, 10, 30, 18)),
      ]);

      expect(counts[DateTime(2026, 11, 2)], 2);
      expect(counts[DateTime(2026, 10, 26)], 1);
    });
  });

  testWidgets('week headers show the goal counter, green once met', (
    tester,
  ) async {
    final entries = [
      _entry('a', DateTime(2026, 11, 3, 18)),
      _entry('b', DateTime(2026, 11, 2, 18)),
      _entry('c', DateTime(2026, 10, 27, 18)),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              HistoryFeedSliver(
                sections: groupHistoryFeed(entries),
                today: DateTime(2026, 11, 3),
                dayKeyFor: (day) => GlobalKey(),
                weekCounts: workoutsPerWeek(entries),
                weeklyGoal: 2,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('2 z 2'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('1 z 2'), findsOneWidget);
    expect(
      find.textContaining('Ten tydzień', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(HistorySessionCard), findsNWidgets(3));
  });

  testWidgets('no goal counter without a goal', (tester) async {
    final entries = [_entry('a', DateTime(2026, 11, 3, 18))];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              HistoryFeedSliver(
                sections: groupHistoryFeed(entries),
                today: DateTime(2026, 11, 3),
                dayKeyFor: (day) => GlobalKey(),
                weekCounts: workoutsPerWeek(entries),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.textContaining(' z '), findsNothing);
  });
}
