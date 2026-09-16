import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/core/sync/sync_coordinator.dart';
import 'package:gym/core/sync/sync_status.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/library/data/exercise_remote_data_source.dart';
import 'package:gym/features/library/data/sync/exercise_sync_engine.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/data/offline_first_training_session_repository.dart';
import 'package:gym/features/training/data/sync/training_plan_sync_engine.dart';
import 'package:gym/features/training/data/sync/training_session_sync_engine.dart';
import 'package:gym/features/training/data/training_plan_remote_data_source.dart';
import 'package:gym/features/training/data/training_session_remote_data_source.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
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
  late _ExerciseRemote exerciseRemote;
  late _SessionRemote sessionRemote;
  late StreamController<bool> network;
  late ValueNotifier<SyncStatus> status;
  late SyncCoordinator coordinator;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('gym_sync_coordinator');
    db = ExerciseDatabase('coordinator.db', directoryOverride: dir.path);
    exerciseRemote = _ExerciseRemote();
    sessionRemote = _SessionRemote();
    network = StreamController<bool>();
    status = ValueNotifier(const SyncStatus());
    coordinator = SyncCoordinator(
      localDb: db,
      exercises: ExerciseSyncEngine(remote: exerciseRemote, localDb: db),
      plans: TrainingPlanSyncEngine(remote: _PlanRemote(), localDb: db),
      sessions: TrainingSessionSyncEngine(remote: sessionRemote, localDb: db),
      status: status,
      networkAvailability: network.stream,
      // Ponawianie „na czas” nie może zasłonić reakcji na sieć w teście.
      initialRetryDelay: const Duration(hours: 1),
      reconnectDelay: const Duration(milliseconds: 10),
      listenToAppLifecycle: false,
    );
  });

  tearDown(() async {
    coordinator.stop();
    await network.close();
    status.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<void> finishWorkoutOffline() async {
    final repo = OfflineFirstTrainingSessionRepository(
      localDb: db,
      syncEngine: TrainingSessionSyncEngine(
        remote: sessionRemote,
        localDb: db,
      )..stop(),
    );
    final session = await repo.startFromPlan(_plan());
    await repo.finish(session.id);
  }

  Future<void> waitFor(bool Function() condition) async {
    for (var i = 0; i < 300 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(condition(), isTrue);
  }

  test('sends a pending workout as soon as the network comes back', () async {
    await finishWorkoutOffline();
    sessionRemote.online = false;

    coordinator.start();
    await waitFor(() => status.value.phase == SyncPhase.offline);
    final attemptsWhileOffline = sessionRemote.createCalls;
    expect(attemptsWhileOffline, greaterThanOrEqualTo(1));

    sessionRemote.online = true;
    network
      ..add(false)
      ..add(true);

    await waitFor(
      () =>
          status.value.phase == SyncPhase.idle &&
          status.value.pendingCount == 0,
    );
    expect(sessionRemote.createCalls, attemptsWhileOffline + 1);
  });

  test('an online event right after a fresh sync does not repeat it', () async {
    coordinator.start();
    await waitFor(
      () =>
          status.value.phase == SyncPhase.idle &&
          status.value.lastSyncedAt != null,
    );
    final pullsAfterStart = exerciseRemote.getAllCalls;

    network.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(exerciseRemote.getAllCalls, pullsAfterStart);
  });
}

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

ApiClient _offlineApi() =>
    ApiClient(baseUrl: 'http://127.0.0.1:9', getToken: () async => '');

class _ExerciseRemote extends ExerciseRemoteDataSource {
  _ExerciseRemote() : super(_offlineApi());

  int getAllCalls = 0;

  @override
  Future<List<Exercise>> getAll({
    MuscleGroup? muscleGroup,
    LibraryFilter? filter,
    String? query,
  }) async {
    getAllCalls++;
    return const [];
  }
}

class _PlanRemote extends TrainingPlanRemoteDataSource {
  _PlanRemote() : super(_offlineApi());

  @override
  Future<List<CustomTrainingPlan>> getAll() async => const [];
}

class _SessionRemote extends TrainingSessionRemoteDataSource {
  _SessionRemote() : super(_offlineApi());

  bool online = true;
  int createCalls = 0;

  @override
  Future<TrainingSession> create(
    TrainingSession session, {
    required Map<String, String?> exerciseServerIdsByLocalId,
  }) async {
    createCalls++;
    if (!online) throw const ApiException('network_error');
    return session.copyWith(serverId: '33333333-3333-4333-8333-333333333333');
  }

  @override
  Future<TrainingSessionHistoryPage> history({
    int limit = 100,
    String? cursor,
    DateTime? updatedSince,
  }) async {
    if (!online) throw const ApiException('network_error');
    return const TrainingSessionHistoryPage(
      items: [],
      nextCursor: null,
      hasMore: false,
    );
  }
}
