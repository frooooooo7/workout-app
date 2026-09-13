import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/library/data/exercise_dto.dart';
import 'package:gym/features/library/data/exercise_remote_data_source.dart';
import 'package:gym/features/library/data/sync/exercise_sync_engine.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/data/offline_first_training_plan_repository.dart';
import 'package:gym/features/training/data/offline_first_training_session_repository.dart';
import 'package:gym/features/training/data/sync/training_plan_sync_engine.dart';
import 'package:gym/features/training/data/sync/training_session_sync_engine.dart';
import 'package:gym/features/training/data/training_plan_remote_data_source.dart';
import 'package:gym/features/training/data/training_session_remote_data_source.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Scenariusze z review offline-first: utrata edycji przy pobieraniu,
/// duplikaty po zgubionej odpowiedzi i wpisy blokujące kolejkę.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dir;
  late ExerciseDatabase db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('gym_sync_conflicts');
    db = ExerciseDatabase('conflicts.db', directoryOverride: dir.path);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<Exercise> insertExercise({
    String localId = _localExerciseId,
    String name = 'Bench',
    String? serverId,
    String? pendingOp,
  }) async {
    final exercise = Exercise(
      id: localId,
      name: name,
      muscles: const [MuscleGroup.chest],
      category: ExerciseCategory.compound,
      isMine: true,
      createdAt: DateTime.utc(2024),
    );
    await db.run(
      (database) => database.insert(
        ExerciseDatabase.tableExercises,
        ExerciseDto.fromDomain(
          exercise,
          serverIdOverride: serverId,
          pendingOp: pendingOp,
        ).toMap(),
      ),
    );
    return exercise;
  }

  group('training plans', () {
    OfflineFirstTrainingPlanRepository stoppedRepo(_PlanRemote remote) {
      return OfflineFirstTrainingPlanRepository(
        localDb: db,
        syncEngine: TrainingPlanSyncEngine(remote: remote, localDb: db)..stop(),
      );
    }

    test('pull keeps offline edits of a plan still waiting to be sent', () async {
      final remote = _PlanRemote();
      final exercise = await insertExercise(serverId: _serverExerciseId);
      final created = await stoppedRepo(remote).create(_plan(exercise));
      await db.run(
        (database) => database.update(
          ExerciseDatabase.tableTrainingPlans,
          {
            'server_id': _serverPlanId,
            'pending_op': 'update',
            'name': 'FBW edited offline',
          },
          where: 'local_id = ?',
          whereArgs: [created.id],
        ),
      );
      remote.serverPlans = [
        CustomTrainingPlan(
          id: _serverPlanId,
          name: 'FBW from server',
          selectedDays: const [1],
        ),
      ];

      await TrainingPlanSyncEngine(remote: remote, localDb: db).pull();

      await db.run((database) async {
        final plans = await database.query(ExerciseDatabase.tableTrainingPlans);
        expect(plans, hasLength(1));
        expect(plans.single['name'], 'FBW edited offline');
        expect(plans.single['pending_op'], 'update');
        final planExercises = await database.query(
          ExerciseDatabase.tableTrainingPlanExercises,
        );
        expect(planExercises, hasLength(1));
      });
    });

    test('pull links a plan created offline instead of duplicating it', () async {
      final remote = _PlanRemote();
      final exercise = await insertExercise(serverId: _serverExerciseId);
      final created = await stoppedRepo(remote).create(_plan(exercise));
      remote.serverPlans = [
        CustomTrainingPlan(
          id: _serverPlanId,
          name: 'FBW',
          selectedDays: const [1, 3, 5],
          clientId: created.id,
        ),
      ];

      await TrainingPlanSyncEngine(remote: remote, localDb: db).pull();

      await db.run((database) async {
        final plans = await database.query(ExerciseDatabase.tableTrainingPlans);
        expect(plans, hasLength(1));
        expect(plans.single['local_id'], created.id);
        expect(plans.single['server_id'], _serverPlanId);
        expect(plans.single['pending_op'], 'create');
      });
    });

    test('flush keeps edits saved while the request was in flight', () async {
      final exercise = await insertExercise(serverId: _serverExerciseId);
      late String localId;
      final remote = _PlanRemote(
        onCreate: () => db.run(
          (database) => database.update(
            ExerciseDatabase.tableTrainingPlans,
            {
              'name': 'FBW v2',
              'updated_at': DateTime.now().millisecondsSinceEpoch + 1000,
            },
            where: 'local_id = ?',
            whereArgs: [localId],
          ),
        ),
      );
      final created = await stoppedRepo(remote).create(_plan(exercise));
      localId = created.id;

      await TrainingPlanSyncEngine(remote: remote, localDb: db).flush();

      await db.run((database) async {
        final plans = await database.query(ExerciseDatabase.tableTrainingPlans);
        expect(plans.single['name'], 'FBW v2');
        expect(plans.single['server_id'], _serverPlanId);
        expect(plans.single['pending_op'], 'update');
      });
    });
  });

  group('exercises', () {
    test('pull adopts an exercise created offline instead of duplicating it', () async {
      await insertExercise(pendingOp: 'create');
      final remote = _ExerciseRemote()
        ..serverExercises = [
          const Exercise(
            id: _serverExerciseId,
            clientId: _localExerciseId,
            name: 'Bench',
            muscles: [MuscleGroup.chest],
            category: ExerciseCategory.compound,
            isMine: true,
          ),
        ];

      await ExerciseSyncEngine(remote: remote, localDb: db).pull();

      await db.run((database) async {
        final rows = await database.query(ExerciseDatabase.tableExercises);
        expect(rows, hasLength(1));
        expect(rows.single['local_id'], _localExerciseId);
        expect(rows.single['server_id'], _serverExerciseId);
        expect(rows.single['pending_op'], 'create');
      });
    });

    test('a rejected exercise does not block the rest of the queue', () async {
      await insertExercise(pendingOp: 'create');
      await insertExercise(
        localId: _otherLocalExerciseId,
        name: 'Rejected',
        pendingOp: 'create',
      );
      final remote = _ExerciseRemote(rejectNames: {'Rejected'});
      final engine = ExerciseSyncEngine(remote: remote, localDb: db);

      await engine.flush();

      await db.run((database) async {
        final bench = await database.query(
          ExerciseDatabase.tableExercises,
          where: 'local_id = ?',
          whereArgs: [_localExerciseId],
        );
        expect(bench.single['server_id'], 'server-Bench');
        expect(bench.single['pending_op'], isNull);

        final rejected = await database.query(
          ExerciseDatabase.tableExercises,
          where: 'local_id = ?',
          whereArgs: [_otherLocalExerciseId],
        );
        expect(rejected.single['pending_op'], 'create');
        expect(rejected.single['sync_error'], 'invalid_body');
      });
      final backlog = await db.countSyncBacklog();
      expect(backlog.pending, 0);
      expect(backlog.failed, 1);

      remote.createCalls.clear();
      await engine.flush();
      expect(remote.createCalls, isEmpty);

      await db.clearSyncErrors();
      expect((await db.countSyncBacklog()).pending, 1);
    });
  });

  group('training sessions', () {
    OfflineFirstTrainingSessionRepository stoppedRepo(_SessionRemote remote) {
      return OfflineFirstTrainingSessionRepository(
        localDb: db,
        syncEngine: TrainingSessionSyncEngine(remote: remote, localDb: db)
          ..stop(),
      );
    }

    test('a session rejected by the server is marked and not retried in a loop', () async {
      final remote = _SessionRemote(rejectCreate: true);
      final repo = stoppedRepo(remote);
      final session = await repo.startFromPlan(_sessionPlan());
      await repo.finish(session.id);
      final engine = TrainingSessionSyncEngine(remote: remote, localDb: db);

      await engine.flush();

      expect(remote.createCalls, 1);
      await db.run((database) async {
        final rows = await database.query(
          ExerciseDatabase.tableTrainingSessions,
        );
        expect(rows.single['pending_op'], 'create');
        expect(rows.single['sync_error'], 'missing_sets');
      });
      expect((await db.countSyncBacklog()).failed, 1);

      await engine.flush();
      expect(remote.createCalls, 1);
    });

    test('a session waits until an exercise created offline has been sent', () async {
      await insertExercise(pendingOp: 'create');
      final remote = _SessionRemote();
      final repo = stoppedRepo(remote);
      final session = await repo.startFromPlan(_sessionPlan());
      await repo.finish(session.id);

      await TrainingSessionSyncEngine(remote: remote, localDb: db).flush();

      expect(remote.createCalls, 0);
      expect((await db.countSyncBacklog()).pending, 2);

      await db.run(
        (database) => database.update(
          ExerciseDatabase.tableExercises,
          {'server_id': _serverExerciseId, 'pending_op': null},
          where: 'local_id = ?',
          whereArgs: [_localExerciseId],
        ),
      );
      await TrainingSessionSyncEngine(remote: remote, localDb: db).flush();

      expect(remote.createCalls, 1);
      expect(remote.lastExerciseIds, {_localExerciseId: _serverExerciseId});
    });
  });
}

const _localExerciseId = '11111111-1111-4111-8111-111111111111';
const _otherLocalExerciseId = '44444444-4444-4444-8444-444444444444';
const _serverExerciseId = '22222222-2222-4222-8222-222222222222';
const _serverPlanId = '33333333-3333-4333-8333-333333333333';
const _serverSessionId = '55555555-5555-4555-8555-555555555555';

CustomTrainingPlan _plan(Exercise exercise) => CustomTrainingPlan(
  name: 'FBW',
  selectedDays: const [1, 3, 5],
  exercises: [
    PlanExercise(
      exercise: exercise,
      sets: [ExerciseSet(weight: '60', reps: '8')],
    ),
  ],
);

CustomTrainingPlan _sessionPlan() => _plan(
  Exercise(
    id: _localExerciseId,
    name: 'Bench',
    muscles: const [MuscleGroup.chest],
    category: ExerciseCategory.compound,
    isMine: true,
    createdAt: DateTime.utc(2026),
  ),
);

ApiClient _offlineApi() =>
    ApiClient(baseUrl: 'http://127.0.0.1:9', getToken: () async => '');

class _PlanRemote extends TrainingPlanRemoteDataSource {
  _PlanRemote({this.onCreate}) : super(_offlineApi());

  final Future<void> Function()? onCreate;
  List<CustomTrainingPlan> serverPlans = const [];

  @override
  Future<List<CustomTrainingPlan>> getAll() async => serverPlans;

  @override
  Future<CustomTrainingPlan> create(
    CustomTrainingPlan plan, {
    required Map<String, String> exerciseServerIdsByLocalId,
  }) async {
    await onCreate?.call();
    return plan.copyWith(id: _serverPlanId);
  }

  @override
  Future<CustomTrainingPlan> update(
    String serverId,
    CustomTrainingPlan plan, {
    required Map<String, String> exerciseServerIdsByLocalId,
  }) async {
    return plan.copyWith(id: serverId);
  }
}

class _ExerciseRemote extends ExerciseRemoteDataSource {
  _ExerciseRemote({this.rejectNames = const {}}) : super(_offlineApi());

  final Set<String> rejectNames;
  List<Exercise> serverExercises = const [];
  final List<String> createCalls = [];

  @override
  Future<List<Exercise>> getAll({
    MuscleGroup? muscleGroup,
    LibraryFilter? filter,
    String? query,
  }) async => serverExercises;

  @override
  Future<Exercise> create({
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
    String? clientId,
  }) async {
    createCalls.add(name);
    if (rejectNames.contains(name)) {
      throw const ApiException('invalid_body', statusCode: 400);
    }
    return Exercise(
      id: 'server-$name',
      name: name,
      muscles: muscles,
      category: category,
      description: description,
      isMine: true,
      clientId: clientId,
    );
  }
}

class _SessionRemote extends TrainingSessionRemoteDataSource {
  _SessionRemote({this.rejectCreate = false}) : super(_offlineApi());

  final bool rejectCreate;
  int createCalls = 0;
  Map<String, String?> lastExerciseIds = const {};

  @override
  Future<TrainingSession> create(
    TrainingSession session, {
    required Map<String, String?> exerciseServerIdsByLocalId,
  }) async {
    createCalls++;
    lastExerciseIds = exerciseServerIdsByLocalId;
    if (rejectCreate) {
      throw const ApiException('missing_sets', statusCode: 400);
    }
    return session.copyWith(serverId: _serverSessionId);
  }
}
