import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/data/offline_first_training_session_repository.dart';
import 'package:gym/features/training/data/sync/training_session_sync_engine.dart';
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

  test(
    'startFromPlan writes an active local session with pending create',
    () async {
      final fixture = await _Fixture.create();
      final repo = fixture.stoppedRepo();

      final session = await repo.startFromPlan(_plan());

      expect(session.status, TrainingSessionStatus.active);
      await fixture.db.run((db) async {
        final rows = await db.query(ExerciseDatabase.tableTrainingSessions);
        expect(rows, hasLength(1));
        expect(rows.single['local_id'], session.id);
        expect(rows.single['status'], 'active');
        expect(rows.single['pending_op'], 'create');
      });

      await fixture.dispose();
    },
  );

  test('startFromPlan blocks a second active local session', () async {
    final fixture = await _Fixture.create();
    final repo = fixture.stoppedRepo();
    await repo.startFromPlan(_plan());

    await expectLater(
      repo.startFromPlan(_plan(name: 'Upper')),
      throwsA(isA<ActiveTrainingSessionException>()),
    );

    await fixture.dispose();
  });

  test('finish updates active session status to completed', () async {
    final fixture = await _Fixture.create();
    final repo = fixture.stoppedRepo();
    final session = await repo.startFromPlan(_plan());

    final finished = await repo.finish(session.id);

    expect(finished.id, session.id);
    expect(finished.status, TrainingSessionStatus.completed);
    await fixture.db.run((db) async {
      final rows = await db.query(ExerciseDatabase.tableTrainingSessions);
      expect(rows, hasLength(1));
      expect(rows.single['status'], 'completed');
    });

    await fixture.dispose();
  });

  test(
    'flush sends active local session once and clears pending state',
    () async {
      final fixture = await _Fixture.create();
      final remote = _SpyTrainingSessionRemote();
      final stoppedSync = TrainingSessionSyncEngine(
        remote: remote,
        localDb: fixture.db,
      )..stop();
      final repo = OfflineFirstTrainingSessionRepository(
        localDb: fixture.db,
        syncEngine: stoppedSync,
      );
      await repo.startFromPlan(_plan());

      final runningSync = TrainingSessionSyncEngine(
        remote: remote,
        localDb: fixture.db,
      );
      await runningSync.flush();

      expect(remote.log, contains('create'));
      await fixture.db.run((db) async {
        final rows = await db.query(ExerciseDatabase.tableTrainingSessions);
        expect(rows.single['server_id'], _serverSessionId);
        expect(rows.single['pending_op'], isNull);
      });

      await fixture.dispose();
    },
  );

  test(
    'flush preserves edits written while create request is in flight',
    () async {
      final fixture = await _Fixture.create();
      late String localId;
      final remote = _SpyTrainingSessionRemote(
        onCreate: (session) async {
          localId = session.id;
          await fixture.db.run((db) async {
            await db.update(
              ExerciseDatabase.tableTrainingSessions,
              {
                'server_id': null,
                'note': 'typed during sync',
                'updated_at': DateTime.now().millisecondsSinceEpoch + 1000,
                'pending_op': 'create',
              },
              where: 'local_id = ?',
              whereArgs: [localId],
            );
          });
        },
      );
      final stoppedSync = TrainingSessionSyncEngine(
        remote: remote,
        localDb: fixture.db,
      )..stop();
      final repo = OfflineFirstTrainingSessionRepository(
        localDb: fixture.db,
        syncEngine: stoppedSync,
      );
      await repo.startFromPlan(_plan());

      final runningSync = TrainingSessionSyncEngine(
        remote: remote,
        localDb: fixture.db,
      );
      await runningSync.flush();

      await fixture.db.run((db) async {
        final rows = await db.query(ExerciseDatabase.tableTrainingSessions);
        expect(rows.single['server_id'], _serverSessionId);
        expect(rows.single['note'], 'typed during sync');
        expect(rows.single['pending_op'], 'update');
      });

      await fixture.dispose();
    },
  );
}

const _exerciseId = '11111111-1111-4111-8111-111111111111';
const _serverSessionId = '33333333-3333-4333-8333-333333333333';

CustomTrainingPlan _plan({String name = 'FBW'}) {
  final exercise = Exercise(
    id: _exerciseId,
    name: 'Bench',
    muscles: const [MuscleGroup.chest],
    category: ExerciseCategory.compound,
    isMine: true,
    createdAt: DateTime.utc(2026),
  );
  return CustomTrainingPlan(
    name: name,
    exercises: [
      PlanExercise(
        exercise: exercise,
        sets: [ExerciseSet(weight: '60', reps: '8')],
      ),
    ],
  );
}

class _Fixture {
  _Fixture(this.dir, this.db);

  final Directory dir;
  final ExerciseDatabase db;

  static Future<_Fixture> create() async {
    final dir = await Directory.systemTemp.createTemp('gym_session_sync');
    return _Fixture(
      dir,
      ExerciseDatabase('sessions.db', directoryOverride: dir.path),
    );
  }

  OfflineFirstTrainingSessionRepository stoppedRepo() {
    final sync = TrainingSessionSyncEngine(
      remote: _SpyTrainingSessionRemote(),
      localDb: db,
    )..stop();
    return OfflineFirstTrainingSessionRepository(localDb: db, syncEngine: sync);
  }

  Future<void> dispose() async {
    await db.close();
    await dir.delete(recursive: true);
  }
}

class _SpyTrainingSessionRemote extends TrainingSessionRemoteDataSource {
  _SpyTrainingSessionRemote({this.onCreate})
    : super(ApiClient(baseUrl: 'http://127.0.0.1:9', getToken: () async => ''));

  final List<String> log = [];
  final Future<void> Function(TrainingSession session)? onCreate;

  @override
  Future<TrainingSession> create(
    TrainingSession session, {
    required Map<String, String?> exerciseServerIdsByLocalId,
  }) async {
    log.add('create');
    await onCreate?.call(session);
    return session.copyWith(serverId: _serverSessionId);
  }

  @override
  Future<TrainingSession> update(
    String serverId,
    TrainingSession session, {
    required Map<String, String?> exerciseServerIdsByLocalId,
  }) async {
    log.add('update:$serverId');
    return session.copyWith(serverId: serverId);
  }
}
