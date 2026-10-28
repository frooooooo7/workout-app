import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/data/offline_first_training_history_repository.dart';
import 'package:gym/features/training/data/offline_first_training_session_repository.dart';
import 'package:gym/features/training/data/sync/training_session_sync_engine.dart';
import 'package:gym/features/training/data/training_history_local_cache.dart';
import 'package:gym/features/training/data/training_history_remote_data_source.dart';
import 'package:gym/features/training/data/training_session_local_history.dart';
import 'package:gym/features/training/data/training_session_remote_data_source.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dir;
  late ExerciseDatabase db;
  late _HistoryRemote remote;
  late OfflineFirstTrainingHistoryRepository history;
  late OfflineFirstTrainingSessionRepository sessions;
  var freshNotices = 0;

  setUp(() async {
    freshNotices = 0;
    dir = await Directory.systemTemp.createTemp('gym_history_repo');
    db = ExerciseDatabase('history.db', directoryOverride: dir.path);
    remote = _HistoryRemote();
    history = OfflineFirstTrainingHistoryRepository(
      remote: remote,
      localCache: TrainingHistoryLocalCache(db),
      localSessions: TrainingSessionLocalHistory(db),
      onFreshData: () => freshNotices++,
      freshDataDebounce: Duration.zero,
    );
    final sessionApi = TrainingSessionRemoteDataSource(_offlineApi());
    sessions = OfflineFirstTrainingSessionRepository(
      localDb: db,
      syncEngine: TrainingSessionSyncEngine(remote: sessionApi, localDb: db)
        ..stop(),
    );
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('first page includes a workout finished offline', () async {
    final session = await sessions.startFromPlan(_plan());
    await sessions.finish(session.id);
    remote.onGetSessions = () async =>
        _page([_serverItem('server-old', DateTime.utc(2020))]);

    final page = await history.getSessions(
      status: TrainingSessionStatus.completed,
    );

    expect(page.items.map((item) => item.id), [session.id, 'server-old']);
    expect(page.isFromCache, isFalse);
  });

  test(
    'offline without cache still shows workouts saved on this phone',
    () async {
      final session = await sessions.startFromPlan(_plan());
      await sessions.finish(session.id);
      remote.onGetSessions = () async =>
          throw const ApiException('network_error');

      final page = await history.getSessions(
        status: TrainingSessionStatus.completed,
      );

      expect(page.isFromCache, isTrue);
      expect(page.items.single.id, session.id);
    },
  );

  test(
    'offline without cache and without local workouts reports the error',
    () async {
      remote.onGetSessions = () async =>
          throw const ApiException('network_error');

      await expectLater(
        history.getSessions(status: TrainingSessionStatus.completed),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('detail of an unsynced workout comes from the phone', () async {
    final session = await sessions.startFromPlan(_plan());
    await sessions.finish(session.id);

    final detail = await history.getSessionDetail(session.id);

    expect(detail.id, session.id);
    expect(detail.exercises, hasLength(1));
    expect(remote.detailCalls, 0);
  });

  test(
    'detail of a synced workout opens from the phone while the server hangs',
    () async {
      final session = await sessions.startFromPlan(_plan());
      await sessions.finish(session.id);
      await _markSynced(db, session.id, serverId: 'server-1');

      // Bez internetu (np. Wi-Fi bez sieci) zapytanie wisi aż do timeoutu.
      final server = Completer<TrainingSessionDetail>();
      remote.onGetDetail = (_) => server.future;

      final detail = await history
          .getSessionDetail('server-1')
          .timeout(const Duration(seconds: 2));

      expect(detail.id, 'server-1');
      expect(detail.exercises.single.exerciseName, 'Bench');
      expect(
        remote.detailCalls,
        1,
        reason: 'server refreshes it in background',
      );

      // Odpowiedź serwera trafia do cache i każe ekranowi przeładować dane.
      server.complete(_serverDetail('server-1', note: 'z serwera'));
      for (var i = 0; i < 200 && freshNotices == 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(freshNotices, 1);
      remote.onGetDetail = (_) async =>
          throw const ApiException('network_error');
      final refreshed = await history.getSessionDetail('server-1');
      expect(refreshed.note, 'z serwera');
    },
  );

  test('offline detail without a phone copy reports the error', () async {
    await expectLater(
      history.getSessionDetail('unknown'),
      throwsA(isA<ApiException>()),
    );
  });

  test('slow server falls back to the cached page', () async {
    remote.onGetSessions = () async =>
        _page([_serverItem('cached', DateTime.utc(2021))]);
    await history.getSessions(status: TrainingSessionStatus.completed);

    final slow = Completer<TrainingSessionPage>();
    remote.onGetSessions = () => slow.future;

    final page = await history.getSessions(
      status: TrainingSessionStatus.completed,
    );

    expect(page.isFromCache, isTrue);
    expect(page.items.single.id, 'cached');

    // Spóźniona odpowiedź odświeża cache w tle i każe ekranom przeczytać
    // dane jeszcze raz. Powiadomienie idzie po zapisie cache, więc po nim
    // następny odczyt widzi już świeżą stronę.
    slow.complete(_page([_serverItem('fresh', DateTime.utc(2022))]));
    for (var i = 0; i < 200 && freshNotices == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(freshNotices, 1, reason: 'screens re-read after fresh data');
    remote.onGetSessions = () async =>
        throw const ApiException('network_error');
    final afterRefresh = await history.getSessions(
      status: TrainingSessionStatus.completed,
    );
    expect(afterRefresh.items.single.id, 'fresh');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(freshNotices, 1);
  });

  test('unchanged server response does not ask screens to reload', () async {
    remote.onGetSessions = () async =>
        _page([_serverItem('same', DateTime.utc(2021))]);
    await history.getSessions(status: TrainingSessionStatus.completed);

    final cachedRead = await history.getSessions(
      status: TrainingSessionStatus.completed,
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(cachedRead.isFromCache, isTrue);
    expect(freshNotices, 0);
  });
}

Future<void> _markSynced(
  ExerciseDatabase db,
  String localId, {
  required String serverId,
}) {
  return db.run(
    (database) => database.update(
      ExerciseDatabase.tableTrainingSessions,
      {'server_id': serverId, 'pending_op': null},
      where: 'local_id = ?',
      whereArgs: [localId],
    ),
  );
}

TrainingSessionDetail _serverDetail(String id, {String? note}) {
  final startedAt = DateTime.utc(2026, 10, 1, 18);
  return TrainingSessionDetail(
    id: id,
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(hours: 1)),
    durationSec: 3600,
    status: TrainingSessionStatus.completed,
    plan: const TrainingPlanSummary(id: '', name: 'FBW'),
    note: note,
    exercises: const [],
    updatedAt: DateTime.now().toUtc(),
  );
}

ApiClient _offlineApi() =>
    ApiClient(baseUrl: 'http://127.0.0.1:9', getToken: () async => '');

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

TrainingSessionPage _page(List<TrainingSessionListItem> items) =>
    TrainingSessionPage(
      items: items,
      nextCursor: null,
      hasMore: false,
      isFromCache: false,
    );

TrainingSessionListItem _serverItem(String id, DateTime startedAt) =>
    TrainingSessionListItem(
      id: id,
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(hours: 1)),
      durationSec: 3600,
      status: TrainingSessionStatus.completed,
      plan: const TrainingPlanSummary(id: '', name: 'Server'),
      exercisesCount: 1,
      completedSetsCount: 1,
      hasNote: false,
      updatedAt: startedAt,
    );

class _HistoryRemote extends TrainingHistoryRemoteDataSource {
  _HistoryRemote() : super(_offlineApi());

  Future<TrainingSessionPage> Function()? onGetSessions;
  int detailCalls = 0;
  Future<TrainingSessionDetail> Function(String sessionId)? onGetDetail;

  @override
  Future<TrainingSessionPage> getSessions({
    String? cursor,
    int limit = 20,
    TrainingSessionStatus? status,
    String? planId,
    String? query,
    DateTime? from,
    DateTime? to,
  }) {
    return onGetSessions!();
  }

  @override
  Future<TrainingSessionDetail> getSessionDetail(String sessionId) async {
    detailCalls++;
    final handler = onGetDetail;
    if (handler != null) return handler(sessionId);
    throw const ApiException('network_error');
  }
}
