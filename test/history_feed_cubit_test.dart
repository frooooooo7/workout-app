import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/models/training_session.dart'
    as session;
import 'package:gym/features/training/domain/repositories/training_history_repository.dart';
import 'package:gym/features/training/domain/repositories/training_stats_repository.dart';
import 'package:gym/features/training/presentation/bloc/history_feed_cubit.dart';
import 'package:gym/features/training/presentation/bloc/training_stats_cubit.dart';

session.TrainingSession _local(String id, DateTime at) =>
    session.TrainingSession(
      id: id,
      planName: 'Push',
      status: session.TrainingSessionStatus.completed,
      startedAt: at.toUtc(),
      finishedAt: at.add(const Duration(hours: 1)).toUtc(),
      exercises: [
        session.TrainingSessionExercise(
          exerciseId: 'e',
          exerciseName: 'Wyciskanie',
          exerciseMuscles: const [],
          exerciseCategory: 'strength',
          sets: [
            session.TrainingSessionSet(
              actualWeight: '80',
              actualReps: '5',
              completed: true,
            ),
          ],
        ),
      ],
    );

TrainingSessionListItem _server(String id, DateTime at) =>
    TrainingSessionListItem(
      id: id,
      startedAt: at.toUtc(),
      endedAt: null,
      durationSec: 0,
      status: TrainingSessionStatus.completed,
      plan: const TrainingPlanSummary(id: 'p', name: 'Plan'),
      exercisesCount: 1,
      completedSetsCount: 1,
      hasNote: false,
      updatedAt: at.toUtc(),
    );

class _Stats implements TrainingStatsRepository {
  List<session.TrainingSession> sessions = [];
  bool fails = false;

  @override
  Future<List<session.TrainingSession>> allCompletedSessions() async {
    if (fails) throw StateError('db');
    return sessions;
  }

  @override
  Future<List<session.TrainingSession>> completedSessionsSince(
    DateTime from,
  ) async => sessions;
}

class _History implements TrainingHistoryRepository {
  List<TrainingSessionListItem> items = [];
  bool fails = false;

  @override
  Future<TrainingSessionDetail> getSessionDetail(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<TrainingSessionPage> getSessions({
    String? cursor,
    int limit = 20,
    TrainingSessionStatus? status,
    String? planId,
    String? query,
    DateTime? from,
    DateTime? to,
  }) async {
    if (fails) throw StateError('offline');
    return TrainingSessionPage(
      items: items,
      nextCursor: null,
      hasMore: false,
      isFromCache: false,
    );
  }
}

void main() {
  final at = DateTime(2026, 10, 12, 18);
  late _Stats stats;
  late _History history;
  late ValueNotifier<int> changes;
  late TrainingStatsCubit statsCubit;
  late HistoryFeedCubit cubit;

  setUp(() {
    stats = _Stats();
    history = _History();
    changes = ValueNotifier<int>(0);
    statsCubit = TrainingStatsCubit(
      stats,
      dataChanges: changes,
      clock: () => DateTime(2026, 11, 1),
    );
    cubit = HistoryFeedCubit(statsCubit, history);
  });

  tearDown(() async {
    await cubit.close();
    await statsCubit.close();
  });

  test('builds the list from local sessions, newest first', () async {
    stats.sessions = [
      _local('old', at),
      _local('new', at.add(const Duration(days: 3))),
    ];
    await cubit.load();
    await pumpEventQueue();

    expect(cubit.state.loading, isFalse);
    expect(cubit.state.fromServer, isFalse);
    expect(cubit.state.entries.map((e) => e.item.id), ['new', 'old']);
    expect(cubit.state.entries.first.lines.single.name, 'Wyciskanie');
  });

  test('the latest workout is compared with the previous one', () async {
    stats.sessions = [
      _local('old', at),
      _local('new', at.add(const Duration(days: 3))),
    ];
    await cubit.load();
    await pumpEventQueue();

    final latest = cubit.state.latest!;
    expect(latest.entry.item.id, 'new');
    // Obie sesje bez planu: porównanie ćwiczeń z ostatnim razem.
    expect(latest.comparison, isNotNull);
    final line = latest.entry.lines.single;
    expect(latest.comparisonOf(line)!.exerciseName, 'Wyciskanie');
  });

  test('the server list gives a latest card without a comparison', () async {
    history.items = [_server('srv', at)];
    await cubit.load();
    await pumpEventQueue();

    expect(cubit.state.fromServer, isTrue);
    expect(cubit.state.latest!.entry.item.id, 'srv');
    expect(cubit.state.latest!.comparison, isNull);
  });

  test(
    'uses the sessions and records the stats cubit already loaded',
    () async {
      stats.sessions = [_local('a', at)];
      await statsCubit.load();
      await pumpEventQueue();

      // Nikt nie wołał load() na liście — dane przyszły ze statystyk.
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.entries.map((e) => e.item.id), ['a']);
    },
  );

  test(
    'falls back to the server list when the phone has no sessions',
    () async {
      history.items = [
        _server('a', at),
        _server('b', at.add(const Duration(days: 1))),
      ];
      await cubit.load();
      await pumpEventQueue();

      expect(cubit.state.fromServer, isTrue);
      expect(cubit.state.entries.map((e) => e.item.id), ['b', 'a']);
      expect(cubit.state.entries.first.lines, isEmpty);
    },
  );

  test('reports a failure only when nothing can be shown', () async {
    stats.fails = true;
    history.fails = true;
    await cubit.load();
    await pumpEventQueue();

    expect(cubit.state.failed, isTrue);
    expect(cubit.state.loading, isFalse);
  });

  test('a local read error still shows the server list', () async {
    stats.fails = true;
    history.items = [_server('a', at)];
    await cubit.load();
    await pumpEventQueue();

    expect(cubit.state.failed, isFalse);
    expect(cubit.state.entries, hasLength(1));
  });

  test('a data change reloads the list', () async {
    stats.sessions = [_local('a', at)];
    await cubit.load();
    await pumpEventQueue();
    expect(cubit.state.entries, hasLength(1));

    stats.sessions = [
      _local('a', at),
      _local('b', at.add(const Duration(days: 1))),
    ];
    changes.value++;
    await pumpEventQueue();
    await statsCubit.load();
    await pumpEventQueue();

    expect(cubit.state.entries, hasLength(2));
  });

  test('deleting the last workout empties the list instead of asking the '
      'server for it back', () async {
    stats.sessions = [_local('a', at)];
    await cubit.load();
    await pumpEventQueue();
    expect(cubit.state.entries, hasLength(1));

    // Serwer o usunięciu jeszcze nie wie i dalej zwraca trening.
    stats.sessions = [];
    history.items = [_server('a', at)];
    await cubit.load();
    await pumpEventQueue();

    expect(cubit.state.entries, isEmpty);
    expect(cubit.state.fromServer, isFalse);
    expect(cubit.state.failed, isFalse);
    expect(cubit.state.loading, isFalse);
  });
}
