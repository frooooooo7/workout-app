import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/services/history_feed_builder.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_compact_row.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_feed_list.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_formatters.dart';
import 'package:gym/features/training/presentation/widgets/workout_history/history_latest_card.dart';

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

Widget _app(Widget sliver, {ScrollController? controller}) => MaterialApp(
  home: Scaffold(
    body: CustomScrollView(controller: controller, slivers: [sliver]),
  ),
);

void main() {
  group('groupHistoryFeed', () {
    test('splits months, newest first, keeping every training as a row', () {
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
      expect(sections[0].rows.map((e) => e.item.id), ['a', 'b', 'c']);
      expect(sections[1].rows.map((e) => e.item.id), ['d']);
    });

    test('the latest workout gets no row and is left out of the month', () {
      final sections = groupHistoryFeed([
        _entry('a', DateTime(2026, 11, 3, 18)),
        _entry('b', DateTime(2026, 11, 1, 18)),
        _entry('c', DateTime(2026, 10, 28, 18)),
      ], exceptId: 'a');

      expect(sections[0].rows.map((e) => e.item.id), ['b']);
    });

    test('a month with only the latest workout disappears', () {
      final sections = groupHistoryFeed([
        _entry('a', DateTime(2026, 11, 3, 18)),
        _entry('c', DateTime(2026, 10, 28, 18)),
      ], exceptId: 'a');

      expect(sections.map((s) => s.month), [DateTime(2026, 10)]);
    });
  });

  group('historyLatestWhen', () {
    final today = DateTime(2026, 11, 5);

    test('names today, yesterday and the last few days', () {
      expect(historyLatestWhen(DateTime(2026, 11, 5), today), 'DZIŚ');
      expect(historyLatestWhen(DateTime(2026, 11, 4), today), 'WCZORAJ');
      expect(historyLatestWhen(DateTime(2026, 11, 2), today), '3 DNI TEMU');
    });

    test('counts calendar days across a daylight saving change', () {
      // Wiosenna zmiana czasu (29 III 2026): doba ma 23 godziny.
      final afterChange = DateTime(2026, 3, 30);
      expect(historyLatestWhen(DateTime(2026, 3, 30), afterChange), 'DZIŚ');
      expect(historyLatestWhen(DateTime(2026, 3, 29), afterChange), 'WCZORAJ');
      expect(
        historyLatestWhen(DateTime(2026, 3, 27), afterChange),
        '3 DNI TEMU',
      );
    });

    test('falls back to the date from a week on', () {
      expect(historyLatestWhen(DateTime(2026, 10, 28), today), 'ŚR 28 PAŹ');
    });
  });

  testWidgets('a month is one card of compact rows with a month summary', (
    tester,
  ) async {
    final entries = [
      _entry('a', DateTime(2026, 10, 30, 18), records: 2),
      _entry('b', DateTime(2026, 10, 28, 18)),
      _entry('c', DateTime(2026, 9, 20, 18)),
    ];
    await tester.pumpWidget(
      _app(
        HistoryFeedSliver(
          sections: groupHistoryFeed(entries),
          today: DateTime(2026, 11, 3),
          dayKeyFor: (day) => GlobalKey(),
        ),
      ),
    );

    expect(find.byType(HistoryCompactRow), findsNWidgets(3));
    // Pierwszy miesiąc otwiera „Wcześniej” i niesie nazwę miesiąca w sumie.
    expect(find.text('Wcześniej'), findsOneWidget);
    expect(find.textContaining('Październik · 2 treningi'), findsOneWidget);
    expect(find.text('Wrzesień'), findsOneWidget);
    expect(find.text('2 rekordy'), findsOneWidget);
  });

  testWidgets('the month summary counts only the rows under it', (
    tester,
  ) async {
    final entries = [
      _entry('a', DateTime(2026, 10, 30, 18)),
      _entry('b', DateTime(2026, 10, 28, 18)),
    ];
    await tester.pumpWidget(
      _app(
        HistoryFeedSliver(
          sections: groupHistoryFeed(entries, exceptId: 'a'),
          today: DateTime(2026, 11, 3),
          dayKeyFor: (day) => GlobalKey(),
        ),
      ),
    );

    expect(find.byType(HistoryCompactRow), findsOneWidget);
    expect(find.textContaining('Październik · 1 trening ·'), findsOneWidget);
  });

  testWidgets('only the first row of a day carries its scroll key', (
    tester,
  ) async {
    final keys = <DateTime, GlobalKey>{};
    final entries = [
      _entry('a', DateTime(2026, 10, 30, 18)),
      _entry('b', DateTime(2026, 10, 30, 8)),
      _entry('c', DateTime(2026, 10, 28, 18)),
    ];
    await tester.pumpWidget(
      _app(
        HistoryFeedSliver(
          sections: groupHistoryFeed(entries),
          today: DateTime(2026, 11, 3),
          dayKeyFor: (day) => keys.putIfAbsent(day, GlobalKey.new),
        ),
      ),
    );

    expect(keys.keys, [DateTime(2026, 10, 30), DateTime(2026, 10, 28)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only the current month header stays pinned at the top', (
    tester,
  ) async {
    final entries = [
      for (var month = 11; month >= 8; month--)
        for (var d = 20; d >= 2; d -= 3)
          _entry('$month-$d', DateTime(2026, month, d, 18)),
    ];
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _app(
        HistoryFeedSliver(
          sections: groupHistoryFeed(entries),
          today: DateTime(2026, 11, 28),
          dayKeyFor: (day) => GlobalKey(),
        ),
        controller: controller,
      ),
    );

    final titles = {
      'Wcześniej',
      for (final month in [8, 9, 10]) formatMonthName(DateTime(2026, month)),
    };
    final headers = find.byWidgetPredicate(
      (w) => w is Text && titles.contains(w.data),
    );

    // Przewijamy w głąb trzeciego miesiąca: nagłówki wcześniejszych miesięcy
    // muszą już zniknąć, a nie piętrzyć się u góry.
    controller.jumpTo(controller.position.maxScrollExtent * 0.55);
    await tester.pump();
    await tester.pump();

    final pinned = [
      for (final element in headers.evaluate())
        tester.getTopLeft(find.byWidget(element.widget)).dy,
    ].where((top) => top < 90).toList();
    // Nagłówek miesiąca ma 44 px: drugi pod pierwszym znaczyłby stos.
    expect(pinned, hasLength(1));
  });
}
