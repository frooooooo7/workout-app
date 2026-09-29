import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/models/training_stats.dart';
import 'package:gym/features/training/domain/repositories/training_stats_repository.dart';
import 'package:gym/features/training/presentation/bloc/training_stats_cubit.dart';

class _Repo implements TrainingStatsRepository {
  _Repo(this.sessions);

  List<TrainingSession> sessions;
  int reads = 0;

  @override
  Future<List<TrainingSession>> allCompletedSessions() async {
    reads++;
    return sessions;
  }

  @override
  Future<List<TrainingSession>> completedSessionsSince(DateTime from) async =>
      sessions;
}

TrainingSession _session(DateTime startLocal) => TrainingSession(
  planName: 'Push',
  status: TrainingSessionStatus.completed,
  startedAt: startLocal.toUtc(),
  finishedAt: startLocal.add(const Duration(minutes: 45)).toUtc(),
  exercises: [
    TrainingSessionExercise(
      exerciseId: '',
      exerciseName: 'Wyciskanie',
      exerciseMuscles: const ['chest'],
      exerciseCategory: 'compound',
      sets: [
        TrainingSessionSet(
          actualWeight: '80',
          actualReps: '10',
          completed: true,
        ),
      ],
    ),
  ],
);

final _now = DateTime(2026, 9, 16, 12);

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out waiting for state');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  group('custom range', () {
    test('selecting dates recomputes without another read', () async {
      final repo = _Repo([
        _session(DateTime(2026, 9, 3, 18)),
        _session(DateTime(2026, 9, 15, 18)),
      ]);
      final cubit = TrainingStatsCubit(repo, clock: () => _now);
      await cubit.load();
      expect(cubit.state.snapshot!.current.workouts, 2);

      final custom = StatsDateRange(DateTime(2026, 9, 1), DateTime(2026, 9, 5));
      cubit.selectCustomRange(custom);

      expect(cubit.state.range, StatsRange.custom);
      expect(cubit.state.customRange, custom);
      expect(cubit.state.snapshot!.range, StatsRange.custom);
      expect(cubit.state.snapshot!.current.workouts, 1);
      expect(repo.reads, 1);

      // Powrót do zakresu z paska nie kasuje zapamiętanych dat…
      cubit.selectRange(StatsRange.week);
      expect(cubit.state.range, StatsRange.week);
      expect(cubit.state.customRange, custom);
      // …a wybranie „Własny” bez dat nic nie robi, a z datami je przywraca.
      cubit.selectRange(StatsRange.custom);
      expect(cubit.state.range, StatsRange.custom);
      expect(cubit.state.snapshot!.current.workouts, 1);
      await cubit.close();
    });

    test(
      'a custom range chosen before the first load is applied by it',
      () async {
        final cubit = TrainingStatsCubit(
          _Repo([_session(DateTime(2026, 9, 3, 18))]),
          clock: () => _now,
        );
        cubit.selectCustomRange(
          StatsDateRange(DateTime(2026, 9, 1), DateTime(2026, 9, 5)),
        );
        await cubit.load();
        expect(cubit.state.snapshot!.range, StatsRange.custom);
        expect(cubit.state.snapshot!.current.workouts, 1);
        await cubit.close();
      },
    );
  });

  group('weekly goal', () {
    test('arrives after the first snapshot and updates it', () async {
      final gate = Completer<int?>();
      final cubit = TrainingStatsCubit(
        _Repo([_session(DateTime(2026, 9, 15, 18))]),
        clock: () => _now,
        weeklyGoalLoader: () => gate.future,
      );
      await cubit.load();
      expect(cubit.state.snapshot!.goal, isNull);
      expect(cubit.state.loading, isFalse);

      gate.complete(3);
      await _until(() => cubit.state.snapshot!.goal != null);
      expect(cubit.state.snapshot!.goal!.goal, 3);
      expect(cubit.state.snapshot!.goal!.workoutsThisWeek, 1);

      // Zmiana zakresu zachowuje cel.
      cubit.selectRange(StatsRange.week);
      expect(cubit.state.snapshot!.goal!.goal, 3);
      await cubit.close();
    });

    test('a goal that fails to load just leaves the card out', () async {
      final cubit = TrainingStatsCubit(
        _Repo([_session(DateTime(2026, 9, 15, 18))]),
        clock: () => _now,
        weeklyGoalLoader: () async => throw Exception('offline'),
      );
      await cubit.load();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(cubit.state.failed, isFalse);
      expect(cubit.state.snapshot!.goal, isNull);
      await cubit.close();
    });

    test('load() fetches the goal again, data changes do not', () async {
      var fetched = 0;
      final changes = ChangeNotifier();
      final repo = _Repo([_session(DateTime(2026, 9, 15, 18))]);
      final cubit = TrainingStatsCubit(
        repo,
        clock: () => _now,
        dataChanges: changes,
        weeklyGoalLoader: () async => ++fetched,
      );
      await cubit.load();
      await _until(() => cubit.state.snapshot!.goal?.goal == 1);

      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      changes.notifyListeners();
      await _until(() => repo.reads == 2);
      expect(fetched, 1);

      await cubit.load();
      await _until(() => cubit.state.snapshot!.goal?.goal == 2);
      await cubit.close();
    });
  });

  group('large history is computed off the main isolate', () {
    List<TrainingSession> history() => [
      for (var i = 0; i < TrainingStatsCubit.isolateThreshold + 20; i++)
        _session(DateTime(2026, 9, 15, 18).subtract(Duration(days: i))),
    ];

    test('matches the direct calculation and keeps ranges in sync', () async {
      final sessions = history();
      final cubit = TrainingStatsCubit(
        _Repo(sessions),
        clock: () => _now,
        weeklyGoalLoader: () async => 4,
      );
      await cubit.load();
      await _until(() => cubit.state.snapshot?.goal != null);

      final snapshot = cubit.state.snapshot!;
      expect(snapshot.range, StatsRange.month);
      expect(snapshot.current.workouts, 29); // 18 sierpnia – 15 września
      expect(snapshot.hasHistory, isTrue);
      expect(snapshot.goal!.goal, 4);

      cubit.selectRange(StatsRange.week);
      // Pasek zakresów reaguje od razu, wykresy po chwili.
      expect(cubit.state.range, StatsRange.week);
      await _until(() => cubit.state.snapshot!.range == StatsRange.week);
      expect(cubit.state.snapshot!.current.workouts, 6); // 10–15 września

      // Szybka seria zmian: liczy się ostatnia, starsze odpowiedzi znikają.
      cubit
        ..selectRange(StatsRange.quarter)
        ..selectRange(StatsRange.year)
        ..selectRange(StatsRange.all);
      await _until(() => cubit.state.snapshot!.range == StatsRange.all);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(cubit.state.range, StatsRange.all);
      expect(cubit.state.snapshot!.range, StatsRange.all);
      expect(cubit.state.snapshot!.current.workouts, sessions.length);
      expect(cubit.state.loading, isFalse);
      await cubit.close();
    });
  });
}
