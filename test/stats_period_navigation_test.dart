import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';
import 'package:gym/features/training/domain/repositories/training_stats_repository.dart';
import 'package:gym/features/training/domain/services/stats/training_stats_calculator.dart';
import 'package:gym/features/training/presentation/bloc/training_stats_cubit.dart';
import 'package:gym/features/training/presentation/screens/training_stats_screen.dart';
import 'package:gym/features/training/presentation/widgets/stats/overview/stats_notes_card.dart';

class _Repo implements TrainingStatsRepository {
  _Repo(this.sessions);

  final List<TrainingSession> sessions;

  @override
  Future<List<TrainingSession>> completedSessionsSince(DateTime from) async =>
      sessions;

  @override
  Future<List<TrainingSession>> allCompletedSessions() async => sessions;
}

TrainingSession _session(
  DateTime startLocal, {
  String exercise = 'Wyciskanie',
  String weight = '80',
}) => TrainingSession(
  planName: 'Push',
  status: TrainingSessionStatus.completed,
  startedAt: startLocal.toUtc(),
  finishedAt: startLocal.add(const Duration(minutes: 45)).toUtc(),
  exercises: [
    TrainingSessionExercise(
      exerciseId: exercise,
      exerciseName: exercise,
      exerciseMuscles: const ['chest'],
      exerciseCategory: 'compound',
      sets: [
        TrainingSessionSet(
          actualWeight: weight,
          actualReps: '5',
          completed: true,
        ),
      ],
    ),
  ],
);

final _now = DateTime(2026, 9, 16, 12);

void main() {
  group('calendar periods', () {
    test('offset moves to an earlier month and flags earlier history', () {
      final sessions = [
        _session(DateTime(2026, 9, 15, 18)),
        _session(DateTime(2026, 8, 20, 18)),
        _session(DateTime(2026, 8, 2, 18)),
      ];
      final september = TrainingStatsCalculator.compute(
        sessions,
        range: StatsRange.month,
        now: _now,
      );
      expect(september.current.workouts, 1);
      expect(september.hasEarlier, isTrue);

      final august = TrainingStatsCalculator.compute(
        sessions,
        range: StatsRange.month,
        now: _now,
        offset: 1,
      );
      expect(august.offset, 1);
      expect(august.current.workouts, 2);
      expect(august.previous!.workouts, 0);
      expect(august.hasEarlier, isFalse);
    });

    test('a record is counted once per exercise in the period', () {
      final snapshot = TrainingStatsCalculator.compute(
        [
          _session(DateTime(2026, 9, 2, 18), weight: '80'),
          _session(DateTime(2026, 9, 5, 18), weight: '85'),
          _session(DateTime(2026, 9, 9, 18), weight: '90'),
          _session(DateTime(2026, 9, 12, 18), exercise: 'Przysiad'),
        ],
        range: StatsRange.month,
        now: _now,
      );
      // Wyciskanie pobiło rekord trzy razy, ale to jedno ćwiczenie.
      expect(snapshot.recordsCount, lessThanOrEqualTo(2));
      expect(
        {for (final r in snapshot.records) r.exerciseKey}.length,
        snapshot.records.length,
      );
    });
  });

  group('TrainingStatsCubit.shiftPeriod', () {
    test('goes back, forth and resets on a new range', () async {
      final cubit = TrainingStatsCubit(
        _Repo([
          _session(DateTime(2026, 9, 15, 18)),
          _session(DateTime(2026, 7, 20, 18)),
        ]),
        clock: () => _now,
      );
      await cubit.load();
      expect(cubit.state.offset, 0);

      cubit.shiftPeriod(1); // nie ma „przyszłości”
      expect(cubit.state.offset, 0);

      cubit.shiftPeriod(-1);
      expect(cubit.state.offset, 1);
      expect(cubit.state.snapshot!.window.start, DateTime(2026, 8));

      cubit.shiftPeriod(-1);
      expect(cubit.state.snapshot!.window.start, DateTime(2026, 7));
      expect(cubit.state.snapshot!.current.workouts, 1);

      cubit.shiftPeriod(-1); // przed lipcem nie ma treningów
      expect(cubit.state.offset, 2);

      cubit.shiftPeriod(1);
      expect(cubit.state.offset, 1);

      cubit.selectRange(StatsRange.year);
      expect(cubit.state.offset, 0);
      expect(cubit.state.snapshot!.window.start, DateTime(2026));
      await cubit.close();
    });
  });

  group('notes', () {
    test('at most two, attention only, no inactivity for a past period', () {
      const insights = [
        StatsInsight(
          kind: StatsInsightKind.inactivity,
          tone: StatsInsightTone.attention,
          text: 'a',
        ),
        StatsInsight(
          kind: StatsInsightKind.records,
          tone: StatsInsightTone.positive,
          text: 'b',
        ),
        StatsInsight(
          kind: StatsInsightKind.plateau,
          tone: StatsInsightTone.attention,
          text: 'c',
        ),
        StatsInsight(
          kind: StatsInsightKind.neglected,
          tone: StatsInsightTone.attention,
          text: 'd',
        ),
      ];
      final base = TrainingStatsCalculator.compute(
        [_session(DateTime(2026, 9, 15, 18))],
        range: StatsRange.month,
        now: _now,
      );
      TrainingStatsSnapshot with0(int offset) => TrainingStatsSnapshot(
        range: base.range,
        window: base.window,
        current: base.current,
        previous: base.previous,
        trainingDays: base.trainingDays,
        recordsCount: base.recordsCount,
        previousRecordsCount: base.previousRecordsCount,
        currentStreakWeeks: base.currentStreakWeeks,
        bestStreakWeeks: base.bestStreakWeeks,
        series: base.series,
        activity: base.activity,
        habits: base.habits,
        muscles: base.muscles,
        records: base.records,
        bests: base.bests,
        exercises: base.exercises,
        progressFrom: base.progressFrom,
        hasHistory: true,
        offset: offset,
        insights: insights,
      );
      expect(
        buildStatsNotes(with0(0), onOpen: (_) => null).map((n) => n.text),
        ['a', 'c'],
      );
      expect(
        buildStatsNotes(with0(1), onOpen: (_) => null).map((n) => n.text),
        ['c', 'd'],
      );
    });
  });

  testWidgets('arrows change the period; next is off on the current one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingStatsScreen(
          repository: _Repo([
            _session(DateTime(2026, 9, 15, 18)),
            _session(DateTime(2026, 8, 15, 18)),
          ]),
          dataChanges: ChangeNotifier(),
          clock: () => _now,
          weeklyGoalLoader: () async => null,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Wrzesień 2026'), findsOneWidget);
    expect(find.text('porównanie z sierpniem'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stats-period-next')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Wrzesień 2026'), findsOneWidget, reason: 'next is off');

    await tester.tap(find.byKey(const ValueKey('stats-period-prev')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sierpień 2026'), findsOneWidget);
    expect(find.text('porównanie z lipcem'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stats-period-prev')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sierpień 2026'), findsOneWidget, reason: 'no history');

    await tester.tap(find.byKey(const ValueKey('stats-period-next')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Wrzesień 2026'), findsOneWidget);
  });
}
