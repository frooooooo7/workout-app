import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/library/data/exercise_dto.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/data/offline_first_training_plan_repository.dart';
import 'package:gym/features/training/data/sync/training_plan_sync_engine.dart';
import 'package:gym/features/training/data/training_plan_remote_data_source.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('create writes training plan locally with pending_op=create', () async {
    final fixture = await _Fixture.create();
    final repo = fixture.stoppedRepo();
    final exercise = await fixture.insertExercise(serverId: _serverExerciseId);

    final created = await repo.create(_plan(exercise));

    await fixture.db.run((db) async {
      final rows = await db.query(ExerciseDatabase.tableTrainingPlans);
      expect(rows, hasLength(1));
      expect(rows.single['local_id'], created.id);
      expect(rows.single['pending_op'], 'create');
      expect(rows.single['server_id'], isNull);
    });

    await fixture.dispose();
  });

  test('update pending create keeps pending_op=create', () async {
    final fixture = await _Fixture.create();
    final repo = fixture.stoppedRepo();
    final exercise = await fixture.insertExercise(serverId: _serverExerciseId);
    final created = await repo.create(_plan(exercise));

    await repo.update(created.copyWith(name: 'FBW v2'));

    await fixture.db.run((db) async {
      final rows = await db.query(ExerciseDatabase.tableTrainingPlans);
      expect(rows.single['name'], 'FBW v2');
      expect(rows.single['pending_op'], 'create');
    });

    await fixture.dispose();
  });

  test(
    'delete pending create removes local plan without remote delete',
    () async {
      final fixture = await _Fixture.create();
      final remote = _SpyTrainingPlanRemote();
      final sync = TrainingPlanSyncEngine(remote: remote, localDb: fixture.db)
        ..stop();
      final repo = OfflineFirstTrainingPlanRepository(
        localDb: fixture.db,
        syncEngine: sync,
      );
      final exercise = await fixture.insertExercise(
        serverId: _serverExerciseId,
      );
      final created = await repo.create(_plan(exercise));

      await repo.delete(created.id);

      await fixture.db.run((db) async {
        final plans = await db.query(ExerciseDatabase.tableTrainingPlans);
        expect(plans, isEmpty);
        final logs = await db.query(ExerciseDatabase.tableOutboxLog);
        expect(logs.single['op'], 'skipped_pending_plan_create');
      });
      expect(remote.log.where((e) => e.startsWith('delete')), isEmpty);

      await fixture.dispose();
    },
  );

  test('flush create sends plan and stores server_id', () async {
    final fixture = await _Fixture.create();
    final remote = _SpyTrainingPlanRemote();
    final sync = TrainingPlanSyncEngine(remote: remote, localDb: fixture.db);
    final repo = OfflineFirstTrainingPlanRepository(
      localDb: fixture.db,
      syncEngine: sync..stop(),
    );
    final exercise = await fixture.insertExercise(serverId: _serverExerciseId);
    final created = await repo.create(_plan(exercise));

    final runningSync = TrainingPlanSyncEngine(
      remote: remote,
      localDb: fixture.db,
    );
    await runningSync.flush();

    expect(remote.log, contains('create'));
    await fixture.db.run((db) async {
      final rows = await db.query(ExerciseDatabase.tableTrainingPlans);
      expect(rows.single['local_id'], created.id);
      expect(rows.single['server_id'], _serverPlanId);
      expect(rows.single['pending_op'], isNull);
    });

    await fixture.dispose();
  });

  test(
    'flush update repairs stale local server_id with idempotent create',
    () async {
      final fixture = await _Fixture.create();
      final remote = _SpyTrainingPlanRemote();
      final sync = TrainingPlanSyncEngine(remote: remote, localDb: fixture.db);
      final repo = OfflineFirstTrainingPlanRepository(
        localDb: fixture.db,
        syncEngine: sync..stop(),
      );
      final exercise = await fixture.insertExercise(
        serverId: _serverExerciseId,
      );
      final created = await repo.create(_plan(exercise));

      await fixture.db.run((db) async {
        await db.update(
          ExerciseDatabase.tableTrainingPlans,
          {'server_id': created.id, 'pending_op': 'update'},
          where: 'local_id = ?',
          whereArgs: [created.id],
        );
      });

      final runningSync = TrainingPlanSyncEngine(
        remote: remote,
        localDb: fixture.db,
      );
      await runningSync.flush();

      expect(remote.log, contains('create'));
      expect(remote.log.where((e) => e.startsWith('update')), isEmpty);
      await fixture.db.run((db) async {
        final rows = await db.query(ExerciseDatabase.tableTrainingPlans);
        expect(rows.single['local_id'], created.id);
        expect(rows.single['server_id'], _serverPlanId);
        expect(rows.single['pending_op'], isNull);
      });

      await fixture.dispose();
    },
  );

  test('flush defers plan when an exercise has no server_id yet', () async {
    final fixture = await _Fixture.create();
    final remote = _SpyTrainingPlanRemote();
    final sync = TrainingPlanSyncEngine(remote: remote, localDb: fixture.db);
    final repo = OfflineFirstTrainingPlanRepository(
      localDb: fixture.db,
      syncEngine: sync..stop(),
    );
    final exercise = await fixture.insertExercise();
    await repo.create(_plan(exercise));

    final runningSync = TrainingPlanSyncEngine(
      remote: remote,
      localDb: fixture.db,
    );
    await runningSync.flush();

    expect(remote.log, isNot(contains('create')));
    await fixture.db.run((db) async {
      final rows = await db.query(ExerciseDatabase.tableTrainingPlans);
      expect(rows.single['pending_op'], 'create');
    });

    await fixture.dispose();
  });
  test('rest, supersets and plan look survive the local round trip', () async {
    final fixture = await _Fixture.create();
    final repo = fixture.stoppedRepo();
    final exercise = await fixture.insertExercise(serverId: _serverExerciseId);

    final created = await repo.create(_customizedPlan(exercise));
    final loaded = (await repo.getAll()).single;

    _expectCustomized(loaded);
    expect(loaded.id, created.id);
    await fixture.dispose();
  });

  test(
    'flush keeps rest, supersets and plan look from the server reply',
    () async {
      final fixture = await _Fixture.create();
      final remote = _SpyTrainingPlanRemote();
      final repo = OfflineFirstTrainingPlanRepository(
        localDb: fixture.db,
        syncEngine: TrainingPlanSyncEngine(remote: remote, localDb: fixture.db)
          ..stop(),
      );
      final exercise = await fixture.insertExercise(
        serverId: _serverExerciseId,
      );
      await repo.create(_customizedPlan(exercise));

      await TrainingPlanSyncEngine(remote: remote, localDb: fixture.db).flush();

      _expectCustomized((await repo.getAll()).single);
      await fixture.dispose();
    },
  );

  test('the request body carries the new fields', () {
    final remote = _SpyTrainingPlanRemote();
    final exercise = Exercise(
      id: 'local-ex',
      name: 'Wyciskanie',
      muscles: const [],
      category: ExerciseCategory.values.first,
    );
    final body = remote.toBody(
      _customizedPlan(exercise),
      exerciseServerIdsByLocalId: const {'local-ex': _serverExerciseId},
    );

    expect(body['defaultRestSeconds'], 150);
    expect(body['colorKey'], 'sky');
    expect(body['iconKey'], 'bolt');
    expect(body['goal'], 'hypertrophy');
    expect(body['progressionStepKg'], 1.25);
    expect(body['highlightPlanColor'], false);
    expect(body['showRir'], false);
    expect(body['showTempo'], true);
    final exercises = body['exercises'] as List;
    expect((exercises[0] as Map)['restSeconds'], 180);
    expect((exercises[0] as Map)['supersetGroup'], 'A');
    expect((exercises[1] as Map)['restSeconds'], isNull);
  });
}

const _localExerciseId = '11111111-1111-4111-8111-111111111111';
CustomTrainingPlan _customizedPlan(Exercise exercise) => CustomTrainingPlan(
  name: 'Góra A',
  selectedDays: const [1, 4],
  defaultRestSeconds: 150,
  colorKey: 'sky',
  iconKey: 'bolt',
  goal: PlanGoal.hypertrophy,
  progressionStepKg: 1.25,
  highlightPlanColor: false,
  showRir: false,
  exercises: [
    PlanExercise(
      exercise: exercise,
      restSeconds: 180,
      supersetGroup: 'A',
      sets: [ExerciseSet(weight: '24', reps: '10')],
    ),
    PlanExercise(
      exercise: exercise,
      supersetGroup: 'A',
      sets: [ExerciseSet(reps: '15')],
    ),
  ],
);

void _expectCustomized(CustomTrainingPlan plan) {
  expect(plan.defaultRestSeconds, 150);
  expect(plan.colorKey, 'sky');
  expect(plan.iconKey, 'bolt');
  expect(plan.goal, PlanGoal.hypertrophy);
  expect(plan.progressionStepKg, 1.25);
  expect(plan.highlightPlanColor, isFalse);
  expect(plan.showRir, isFalse);
  expect(plan.showTempo, isTrue);
  expect(plan.exercises.map((e) => e.restSeconds), [180, null]);
  expect(plan.exercises.map((e) => e.supersetGroup), ['A', 'A']);
}

const _serverExerciseId = '22222222-2222-4222-8222-222222222222';
const _serverPlanId = '33333333-3333-4333-8333-333333333333';

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

class _Fixture {
  _Fixture(this.dir, this.db);

  final Directory dir;
  final ExerciseDatabase db;

  static Future<_Fixture> create() async {
    final dir = await Directory.systemTemp.createTemp('gym_plan_sync');
    return _Fixture(
      dir,
      ExerciseDatabase('plans.db', directoryOverride: dir.path),
    );
  }

  OfflineFirstTrainingPlanRepository stoppedRepo() {
    final sync = TrainingPlanSyncEngine(
      remote: _SpyTrainingPlanRemote(),
      localDb: db,
    )..stop();
    return OfflineFirstTrainingPlanRepository(localDb: db, syncEngine: sync);
  }

  Future<Exercise> insertExercise({String? serverId}) async {
    final exercise = Exercise(
      id: _localExerciseId,
      name: 'Bench',
      muscles: const [MuscleGroup.chest],
      category: ExerciseCategory.compound,
      isMine: true,
      createdAt: DateTime.utc(2024),
    );
    await db.run((database) async {
      await database.insert(
        ExerciseDatabase.tableExercises,
        ExerciseDto.fromDomain(exercise, serverIdOverride: serverId).toMap(),
      );
    });
    return exercise;
  }

  Future<void> dispose() async {
    await db.close();
    await dir.delete(recursive: true);
  }
}

class _SpyTrainingPlanRemote extends TrainingPlanRemoteDataSource {
  _SpyTrainingPlanRemote()
    : super(ApiClient(baseUrl: 'http://127.0.0.1:9', getToken: () async => ''));

  final List<String> log = [];

  @override
  Future<List<CustomTrainingPlan>> getAll() async {
    log.add('getAll');
    return const [];
  }

  @override
  Future<CustomTrainingPlan> create(
    CustomTrainingPlan plan, {
    required Map<String, String> exerciseServerIdsByLocalId,
  }) async {
    log.add('create');
    return plan.copyWith(id: _serverPlanId);
  }

  @override
  Future<CustomTrainingPlan> update(
    String serverId,
    CustomTrainingPlan plan, {
    required Map<String, String> exerciseServerIdsByLocalId,
  }) async {
    log.add('update:$serverId');
    return plan.copyWith(id: serverId);
  }

  @override
  Future<void> delete(String serverId) async {
    log.add('delete:$serverId');
  }
}
