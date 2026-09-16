import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/data/local_training_stats_repository.dart';
import 'package:gym/features/training/data/offline_first_training_history_repository.dart';
import 'package:gym/features/training/data/offline_first_training_session_repository.dart';
import 'package:gym/features/training/data/sync/training_session_sync_engine.dart';
import 'package:gym/features/training/data/training_history_local_cache.dart';
import 'package:gym/features/training/data/training_history_remote_data_source.dart';
import 'package:gym/features/training/data/training_session_local_history.dart';
import 'package:gym/features/training/data/training_session_remote_data_source.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dir;
  late ExerciseDatabase db;
  late _Remote remote;
  late TrainingSessionSyncEngine engine;
  late OfflineFirstTrainingSessionRepository repo;
  late TrainingSessionLocalHistory localHistory;
  var dataChanges = 0;

  setUp(() async {
    dataChanges = 0;
    dir = await Directory.systemTemp.createTemp('gym_session_delete_pull');
    db = ExerciseDatabase('sessions.db', directoryOverride: dir.path);
    remote = _Remote();
    engine = TrainingSessionSyncEngine(
      remote: remote,
      localDb: db,
      onDataChanged: () => dataChanges++,
    );
    // Repozytorium z zatrzymanym silnikiem — wysyłkę wołamy ręcznie.
    repo = OfflineFirstTrainingSessionRepository(
      localDb: db,
      syncEngine: TrainingSessionSyncEngine(remote: remote, localDb: db)
        ..stop(),
      remote: remote,
    );
    localHistory = TrainingSessionLocalHistory(db);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<String> finishedLocalSession({bool synced = false}) async {
    final session = await repo.startFromPlan(_plan());
    await repo.finish(session.id);
    if (synced) await engine.flush();
    return session.id;
  }

  Future<List<Map<String, Object?>>> sessionRows() =>
      db.run((db) => db.query(ExerciseDatabase.tableTrainingSessions));

  Future<int> childRows() => db.run((db) async {
    final exercises = await db.query(
      ExerciseDatabase.tableTrainingSessionExercises,
    );
    final sets = await db.query(ExerciseDatabase.tableTrainingSessionSets);
    return exercises.length + sets.length;
  });

  group('delete', () {
    test('synced session is hidden at once and deleted by server id', () async {
      final localId = await finishedLocalSession(synced: true);
      final serverId = (await sessionRows()).single['server_id'] as String;
      final stats = LocalTrainingStatsRepository(localHistory);

      await repo.delete(localId);

      expect(await repo.getById(localId), isNull);
      expect(await repo.getById(serverId), isNull);
      expect(
        await localHistory.finishedSessions(includeSynced: true),
        isEmpty,
      );
      expect(await stats.completedSessionsSince(DateTime.utc(2000)), isEmpty);
      expect(await localHistory.pendingDeletionIds(), {localId, serverId});
      expect(await childRows(), 0, reason: 'exercises and sets go at once');
      expect((await db.countSyncBacklog()).pending, 1);

      await engine.flush();

      expect(remote.log, contains('delete:$serverId'));
      expect(remote.log.where((e) => e.startsWith('deleteByClientId')), isEmpty);
      expect(await sessionRows(), isEmpty);
      expect((await db.countSyncBacklog()).pending, 0);
      expect(dataChanges, greaterThan(0));
    });

    test('unsynced session deleted offline is sent by client id later', () async {
      final localId = await finishedLocalSession();
      remote.online = false;

      await repo.delete(localId);
      await engine.flush();

      final rows = await sessionRows();
      expect(rows.single['pending_op'], 'delete');
      expect(rows.single['sync_error'], isNull, reason: 'offline is transient');
      expect(remote.createdIds, isEmpty, reason: 'deleted sessions are not created');

      remote.online = true;
      await engine.flush();

      expect(remote.log, ['deleteByClientId:$localId']);
      expect(await sessionRows(), isEmpty);
    });

    test('session known only from server history gets a tombstone row', () async {
      await repo.delete(_serverOnlyId);

      expect(await localHistory.pendingDeletionIds(), {_serverOnlyId});
      expect(await repo.getById(_serverOnlyId), isNull);

      await engine.flush();

      expect(remote.log, ['delete:$_serverOnlyId']);
      expect(await sessionRows(), isEmpty);
    });

    test('server-only delete hides the session in server history and cache', () async {
      final historyRemote = _HistoryRemote()
        ..page = _page([_serverItem(_serverOnlyId), _serverItem('other')]);
      final cache = TrainingHistoryLocalCache(db);
      final history = OfflineFirstTrainingHistoryRepository(
        remote: historyRemote,
        localCache: cache,
        localSessions: localHistory,
      );
      await history.getSessions();
      await cache.saveSessionDetail(
        sessionId: _serverOnlyId,
        payload: const {'id': _serverOnlyId},
        updatedAt: DateTime.utc(2026),
      );

      await repo.delete(_serverOnlyId);

      expect(await cache.readSessionDetail(_serverOnlyId), isNull);
      // Cache (od razu) i świeża odpowiedź serwera, która wciąż ją ma.
      final page = await history.getSessions();
      expect(page.items.map((i) => i.id), ['other']);
      historyRemote.page = _page([_serverItem(_serverOnlyId), _serverItem('other')]);
      final cachedAgain = await history.getSessions();
      expect(cachedAgain.items.map((i) => i.id), ['other']);
      await expectLater(
        history.getSessionDetail(_serverOnlyId),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 410)),
      );
    });

    test('404 on delete counts as success (with client id fallback)', () async {
      final localId = await finishedLocalSession(synced: true);
      final serverId = (await sessionRows()).single['server_id'] as String;
      remote.deleteStatus = 404;

      await repo.delete(localId);
      await engine.flush();

      expect(remote.log, ['delete:$serverId', 'deleteByClientId:$localId']);
      expect(await sessionRows(), isEmpty);
      final backlog = await db.countSyncBacklog();
      expect(backlog.pending + backlog.failed, 0);
    });

    test('delete requested while create is in flight stays a delete', () async {
      final session = await repo.startFromPlan(_plan());
      await repo.finish(session.id);
      remote.onCreate = () => repo.delete(session.id);

      await engine.flush();

      final rows = await sessionRows();
      expect(rows.single['pending_op'], 'delete');
      expect(rows.single['server_id'], isNotNull);

      remote.onCreate = null;
      await engine.flush();
      expect(remote.log.last, startsWith('delete:'));
      expect(await sessionRows(), isEmpty);
    });
  });

  group('410 session_deleted', () {
    test('on update removes the local session without PUT→POST fallback', () async {
      final localId = await finishedLocalSession(synced: true);
      final session = (await repo.getById(localId))!;
      await repo.save(session.copyWith(note: 'edited'));
      remote.updateStatus = 410;
      final createsBefore = remote.createdIds.length;
      dataChanges = 0;

      await engine.flush();

      expect(await sessionRows(), isEmpty);
      expect(await childRows(), 0);
      expect(remote.createdIds.length, createsBefore);
      final backlog = await db.countSyncBacklog();
      expect(backlog.pending + backlog.failed, 0, reason: 'no rejection banner');
      expect(dataChanges, 1);
    });

    test('on create removes the local session', () async {
      await finishedLocalSession();
      remote.createStatus = 410;

      await engine.flush();

      expect(await sessionRows(), isEmpty);
      final backlog = await db.countSyncBacklog();
      expect(backlog.pending + backlog.failed, 0);
    });

    test('direct share of a server-only session reports deletion', () async {
      remote.shareStatus = 410;

      await expectLater(
        repo.setSharedToProfile(_serverOnlyId, true),
        throwsA(isA<TrainingSessionDeletedException>()),
      );
    });

    test('share and save of a session pending deletion report deletion', () async {
      final localId = await finishedLocalSession(synced: true);
      final session = (await repo.getById(localId))!;
      await repo.delete(localId);

      await expectLater(
        repo.setSharedToProfile(localId, true),
        throwsA(isA<TrainingSessionDeletedException>()),
      );
      await expectLater(
        repo.save(session.copyWith(note: 'late edit')),
        throwsA(isA<TrainingSessionDeletedException>()),
      );
    });
  });

  group('pull', () {
    test('first pull downloads full history and stores the high-water mark', () async {
      remote.historyPages = [
        _historyPage(
          [_pulled('a', updatedAt: DateTime.utc(2026, 9, 1, 10))],
          nextCursor: 'c1',
        ),
        _historyPage([_pulled('b', updatedAt: DateTime.utc(2026, 9, 2, 10))]),
      ];

      await engine.pull();

      expect(remote.historyCalls.map((c) => c.updatedSince), [null, null]);
      expect(remote.historyCalls.map((c) => c.cursor), [null, 'c1']);
      final rows = await sessionRows();
      expect(rows.map((r) => r['local_id']).toSet(), {'client-a', 'client-b'});
      expect(rows.every((r) => r['pending_op'] == null), isTrue);
      expect(
        await db.readSyncState(TrainingSessionSyncEngine.pullHighWaterMarkKey),
        DateTime.utc(2026, 9, 2, 10).toIso8601String(),
      );
      // Pobrane treningi liczą się do statystyk.
      final stats = LocalTrainingStatsRepository(localHistory);
      expect(await stats.completedSessionsSince(DateTime.utc(2000)), hasLength(2));
      expect(dataChanges, 1);
    });

    test('incremental pull upserts, applies deleted[] idempotently and keeps pending edits', () async {
      remote.historyPages = [
        _historyPage([
          _pulled('a', updatedAt: DateTime.utc(2026, 9, 1)),
          _pulled('b', updatedAt: DateTime.utc(2026, 9, 2)),
          _pulled('d', updatedAt: DateTime.utc(2026, 9, 2, 1)),
        ]),
      ];
      await engine.pull();

      // Niewysłana lokalna edycja B.
      final b = (await repo.getById('client-b'))!;
      await repo.save(b.copyWith(note: 'local edit'));

      final mark = DateTime.utc(2026, 9, 2, 1);
      remote.historyPages = [
        _historyPage(
          [
            _pulled('b', updatedAt: DateTime.utc(2026, 9, 3), note: 'server'),
            _pulled('c', updatedAt: DateTime.utc(2026, 9, 4)),
          ],
          deleted: [
            TrainingSessionTombstone(
              id: 'srv-a',
              clientId: 'client-a',
              deletedAt: DateTime.utc(2026, 9, 5),
            ),
            // Usunięta po server id (bez clientId).
            TrainingSessionTombstone(
              id: 'srv-d',
              deletedAt: DateTime.utc(2026, 9, 5),
            ),
            TrainingSessionTombstone(
              id: 'never-here',
              clientId: 'unknown',
              deletedAt: DateTime.utc(2026, 9, 5),
            ),
          ],
        ),
      ];
      remote.historyCalls.clear();
      dataChanges = 0;

      await engine.pull();

      expect(
        remote.historyCalls.single.updatedSince,
        mark.subtract(TrainingSessionSyncEngine.pullOverlap),
      );
      final ids = (await sessionRows()).map((r) => r['local_id']).toSet();
      expect(ids, {'client-b', 'client-c'});
      final bRow = (await repo.getById('client-b'))!;
      expect(bRow.note, 'local edit', reason: 'pull never overwrites pending_op');
      expect(bRow.pendingOp, 'update');
      expect(
        await db.readSyncState(TrainingSessionSyncEngine.pullHighWaterMarkKey),
        DateTime.utc(2026, 9, 5).toIso8601String(),
      );
      expect(dataChanges, 1);

      // Ta sama odpowiedź drugi raz (zakładka czasu) — nic się nie zmienia.
      remote.historyPages = [
        _historyPage(
          [_pulled('c', updatedAt: DateTime.utc(2026, 9, 4))],
          deleted: [
            TrainingSessionTombstone(
              id: 'srv-a',
              clientId: 'client-a',
              deletedAt: DateTime.utc(2026, 9, 5),
            ),
          ],
        ),
      ];
      dataChanges = 0;
      await engine.pull();
      expect(
        (await sessionRows()).map((r) => r['local_id']).toSet(),
        {'client-b', 'client-c'},
      );
      expect(dataChanges, 0);
    });

    test('deletion from another device wins over an unsynced local edit', () async {
      remote.historyPages = [
        _historyPage([_pulled('b', updatedAt: DateTime.utc(2026, 9, 2))]),
      ];
      await engine.pull();
      final b = (await repo.getById('client-b'))!;
      await repo.save(b.copyWith(note: 'local edit'));

      remote.historyPages = [
        _historyPage(
          const [],
          deleted: [
            TrainingSessionTombstone(
              id: 'srv-b',
              clientId: 'client-b',
              deletedAt: DateTime.utc(2026, 9, 6),
            ),
          ],
        ),
      ];
      await engine.pull();

      expect(await sessionRows(), isEmpty);
    });

    test('pulled item pairs with an unsynced local session by client id', () async {
      final localId = await finishedLocalSession();
      remote.historyPages = [
        _historyPage([
          PulledTrainingSession(
            session: (await repo.getById(localId))!.copyWith(
              serverId: 'srv-local',
            ),
            updatedAt: DateTime.utc(2026, 9, 1),
          ),
        ]),
      ];

      await engine.pull();

      final rows = await sessionRows();
      expect(rows, hasLength(1), reason: 'no duplicate row');
      expect(rows.single['server_id'], 'srv-local');
      expect(rows.single['pending_op'], 'create');
    });

    test('full pull removes synced sessions the server no longer has', () async {
      final localId = await finishedLocalSession(synced: true);
      final pending = await finishedLocalSession();
      remote.historyPages = [
        _historyPage([_pulled('x', updatedAt: DateTime.utc(2026, 9, 1))]),
      ];

      await engine.pull();

      final ids = (await sessionRows()).map((r) => r['local_id']).toSet();
      expect(ids.contains(localId), isFalse);
      expect(ids, containsAll(['client-x', pending]));
    });

    test('pulled synced sessions do not duplicate server history items', () async {
      remote.historyPages = [
        _historyPage([_pulled('a', updatedAt: DateTime.utc(2026, 9, 1))]),
      ];
      await engine.pull();
      final historyRemote = _HistoryRemote()
        ..page = _page([_serverItem('srv-a')]);
      final history = OfflineFirstTrainingHistoryRepository(
        remote: historyRemote,
        localCache: TrainingHistoryLocalCache(db),
        localSessions: localHistory,
      );

      final fresh = await history.getSessions();
      final cached = await history.getSessions();

      expect(fresh.items.map((i) => i.id), ['srv-a']);
      expect(cached.isFromCache, isTrue);
      expect(cached.items.map((i) => i.id), ['srv-a']);
    });

    test('an unsynced edit replaces the server version in history', () async {
      remote.historyPages = [
        _historyPage([_pulled('a', updatedAt: DateTime.utc(2026, 9, 1))]),
      ];
      await engine.pull();
      final a = (await repo.getById('client-a'))!;
      await repo.save(a.copyWith(planName: 'Edited offline'));
      final history = OfflineFirstTrainingHistoryRepository(
        remote: _HistoryRemote()..page = _page([_serverItem('srv-a')]),
        localCache: TrainingHistoryLocalCache(db),
        localSessions: localHistory,
      );

      final page = await history.getSessions();

      expect(page.items, hasLength(1));
      expect(page.items.single.id, 'srv-a');
      expect(page.items.single.plan.name, 'Edited offline');
    });

    test('loadForEdit fetches an old server session that is not local yet', () async {
      final repoWithEngine = OfflineFirstTrainingSessionRepository(
        localDb: db,
        syncEngine: engine,
        remote: remote,
      );
      remote.historyHandler = (call) {
        if (call.updatedSince != null) return _historyPage(const []);
        return call.cursor == null
            ? _historyPage(
                [_pulled('new', updatedAt: DateTime.utc(2026, 9, 1))],
                nextCursor: 'p2',
              )
            : _historyPage([_pulled('old', updatedAt: DateTime.utc(2020))]);
      };
      await db.writeSyncState(
        TrainingSessionSyncEngine.pullHighWaterMarkKey,
        DateTime.utc(2026).toIso8601String(),
      );

      final session = await repoWithEngine.loadForEdit('srv-old');

      expect(session?.id, 'client-old');
      expect(session?.serverId, 'srv-old');
    });
  });
}

const _serverOnlyId = '55555555-5555-4555-8555-555555555555';

CustomTrainingPlan _plan() => CustomTrainingPlan(
  name: 'FBW',
  exercises: [
    PlanExercise(
      exercise: Exercise(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'Bench',
        muscles: const [MuscleGroup.chest],
        category: ExerciseCategory.compound,
        isMine: true,
        createdAt: DateTime.utc(2026),
      ),
      sets: [ExerciseSet(weight: '60', reps: '8')],
    ),
  ],
);

PulledTrainingSession _pulled(
  String key, {
  required DateTime updatedAt,
  String? note,
}) {
  final startedAt = DateTime.utc(2026, 9, 1, 8).add(
    Duration(minutes: key.codeUnits.fold(0, (a, b) => a + b)),
  );
  return PulledTrainingSession(
    updatedAt: updatedAt,
    session: TrainingSession(
      id: 'client-$key',
      serverId: 'srv-$key',
      planName: 'Server $key',
      status: TrainingSessionStatus.completed,
      note: note,
      startedAt: startedAt,
      finishedAt: startedAt.add(const Duration(hours: 1)),
      exercises: [
        TrainingSessionExercise(
          // Ćwiczenie spoza lokalnej bazy — snapshot wystarcza.
          exerciseId: 'remote-exercise-$key',
          exerciseName: 'Squat',
          exerciseMuscles: const ['quads'],
          exerciseCategory: 'compound',
          sets: [
            TrainingSessionSet(
              actualWeight: '100',
              actualReps: '5',
              completed: true,
            ),
          ],
        ),
      ],
    ),
  );
}

TrainingSessionHistoryPage _historyPage(
  List<PulledTrainingSession> items, {
  String? nextCursor,
  List<TrainingSessionTombstone> deleted = const [],
}) {
  return TrainingSessionHistoryPage(
    items: items,
    nextCursor: nextCursor,
    hasMore: nextCursor != null,
    deleted: deleted,
  );
}

TrainingSessionPage _page(List<TrainingSessionListItem> items) =>
    TrainingSessionPage(
      items: items,
      nextCursor: null,
      hasMore: false,
      isFromCache: false,
    );

TrainingSessionListItem _serverItem(String id) => TrainingSessionListItem(
  id: id,
  startedAt: DateTime.utc(2025, 1, 1),
  endedAt: DateTime.utc(2025, 1, 1, 1),
  durationSec: 3600,
  status: TrainingSessionStatus.completed,
  plan: const TrainingPlanSummary(id: '', name: 'Server'),
  exercisesCount: 1,
  completedSetsCount: 1,
  hasNote: false,
  updatedAt: DateTime.utc(2025, 1, 1, 1),
);

ApiClient _offlineApi() =>
    ApiClient(baseUrl: 'http://127.0.0.1:9', getToken: () async => '');

class _HistoryCall {
  const _HistoryCall(this.cursor, this.updatedSince);

  final String? cursor;
  final DateTime? updatedSince;
}

class _Remote extends TrainingSessionRemoteDataSource {
  _Remote() : super(_offlineApi());

  bool online = true;
  int? createStatus;
  int? updateStatus;
  int? deleteStatus;
  int? shareStatus;
  Future<void> Function()? onCreate;
  final List<String> log = [];
  final List<String> createdIds = [];
  final List<_HistoryCall> historyCalls = [];
  List<TrainingSessionHistoryPage> historyPages = [];
  TrainingSessionHistoryPage Function(_HistoryCall call)? historyHandler;

  void _check(int? status) {
    if (!online) throw const ApiException('network_error');
    if (status != null) throw ApiException('error_$status', statusCode: status);
  }

  @override
  Future<TrainingSession> create(
    TrainingSession session, {
    required Map<String, String?> exerciseServerIdsByLocalId,
  }) async {
    _check(createStatus);
    createdIds.add(session.id);
    await onCreate?.call();
    return session.copyWith(serverId: 'srv-${session.id}');
  }

  @override
  Future<TrainingSession> update(
    String serverId,
    TrainingSession session, {
    required Map<String, String?> exerciseServerIdsByLocalId,
  }) async {
    _check(updateStatus);
    log.add('update:$serverId');
    return session.copyWith(serverId: serverId);
  }

  @override
  Future<void> delete(String serverId) async {
    if (!online) throw const ApiException('network_error');
    log.add('delete:$serverId');
    _check(deleteStatus);
  }

  @override
  Future<void> deleteByClientId(String clientId) async {
    if (!online) throw const ApiException('network_error');
    log.add('deleteByClientId:$clientId');
  }

  @override
  Future<TrainingSession> setSharedToProfile(
    String serverId,
    bool shared,
  ) async {
    _check(shareStatus);
    return TrainingSession(
      id: serverId,
      serverId: serverId,
      planName: 'Remote',
      status: TrainingSessionStatus.completed,
      sharedToProfile: shared,
      exercises: const [],
    );
  }

  @override
  Future<TrainingSessionHistoryPage> history({
    int limit = 100,
    String? cursor,
    DateTime? updatedSince,
  }) async {
    _check(null);
    final call = _HistoryCall(cursor, updatedSince);
    historyCalls.add(call);
    final handler = historyHandler;
    if (handler != null) return handler(call);
    if (historyPages.isEmpty) return _historyPage(const []);
    return historyPages.removeAt(0);
  }
}

class _HistoryRemote extends TrainingHistoryRemoteDataSource {
  _HistoryRemote() : super(_offlineApi());

  TrainingSessionPage page = _page(const []);

  @override
  Future<TrainingSessionPage> getSessions({
    String? cursor,
    int limit = 20,
    TrainingSessionStatus? status,
    String? planId,
    String? query,
    DateTime? from,
    DateTime? to,
  }) async => page;

  @override
  Future<TrainingSessionDetail> getSessionDetail(String sessionId) async {
    throw const ApiException('not_found', statusCode: 404);
  }
}
