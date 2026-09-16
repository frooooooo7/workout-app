// Offline-first synchronizacja z PRAWDZIWYM backendem: dwa „urządzenia”
// (osobne bazy sqflite) jednego konta, prawdziwe repozytoria i silniki sync.
//
//   flutter test test/e2e --dart-define=E2E_BASE_URL=http://localhost:3102
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/auth/data/auth_repository.dart';
import 'package:gym/features/auth/domain/models/auth_models.dart';
import 'package:gym/features/account/data/account_remote_data_source.dart';
import 'package:gym/features/feed/data/api_feed_repository.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/library/data/exercise_remote_data_source.dart';
import 'package:gym/features/library/data/offline_first_exercise_repository.dart';
import 'package:gym/features/library/data/sync/exercise_sync_engine.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/data/offline_first_training_history_repository.dart';
import 'package:gym/features/training/data/offline_first_training_session_repository.dart';
import 'package:gym/features/training/data/sync/training_session_sync_engine.dart';
import 'package:gym/features/training/data/training_history_local_cache.dart';
import 'package:gym/features/training/data/training_history_remote_data_source.dart';
import 'package:gym/features/training/data/training_session_local_history.dart';
import 'package:gym/features/training/data/training_session_remote_data_source.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'e2e_config.dart';

/// Jedno urządzenie: baza + silniki + repozytoria jak w `ServiceLocator`.
/// Repozytoria dostają zatrzymane silniki — wysyłkę i pobieranie wołamy
/// jawnie, żeby scenariusz był deterministyczny.
class _Device {
  _Device(this.name, this.storage);

  final String name;
  final MemoryTokenStorage storage;
  late final Directory dir;
  late final ExerciseDatabase db;
  late final ExerciseSyncEngine exerciseSync;
  late final TrainingSessionSyncEngine sessionSync;
  late final OfflineFirstExerciseRepository exercises;
  late final OfflineFirstTrainingSessionRepository sessions;
  late final TrainingSessionLocalHistory localHistory;
  late final OfflineFirstTrainingHistoryRepository history;

  Future<void> open() async {
    dir = await Directory.systemTemp.createTemp('gym_e2e_$name');
    db = ExerciseDatabase('device.db', directoryOverride: dir.path);
    final api = e2eApiClient(storage);
    final exerciseRemote = ExerciseRemoteDataSource(api);
    final sessionRemote = TrainingSessionRemoteDataSource(api);
    exerciseSync = ExerciseSyncEngine(remote: exerciseRemote, localDb: db);
    sessionSync = TrainingSessionSyncEngine(remote: sessionRemote, localDb: db);
    exercises = OfflineFirstExerciseRepository(
      localDb: db,
      syncEngine: ExerciseSyncEngine(remote: exerciseRemote, localDb: db)
        ..stop(),
    );
    sessions = OfflineFirstTrainingSessionRepository(
      localDb: db,
      syncEngine: TrainingSessionSyncEngine(remote: sessionRemote, localDb: db)
        ..stop(),
      remote: sessionRemote,
    );
    localHistory = TrainingSessionLocalHistory(db);
    history = OfflineFirstTrainingHistoryRepository(
      remote: TrainingHistoryRemoteDataSource(api),
      localCache: TrainingHistoryLocalCache(db),
      localSessions: localHistory,
    );
  }

  Future<void> close() async {
    exerciseSync.stop();
    sessionSync.stop();
    await db.close();
    await dir.delete(recursive: true);
  }

  Future<List<Map<String, Object?>>> sessionRows() =>
      db.run((db) => db.query(ExerciseDatabase.tableTrainingSessions));
}

void main() {
  group('offline-first sync (real backend)', skip: e2eSkip, () {
    final storage = MemoryTokenStorage();
    late AuthUser user;
    late _Device phone;
    late _Device tablet;
    late String sessionId;
    late String serverId;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      final auth = await AuthRepository(e2eApiClient(storage)).register(
        email: 'e2e.sync.$e2eRunId@example.com',
        password: e2ePassword,
        firstName: 'Sync',
        lastName: 'E2e',
      );
      user = auth.user;
      storage.token = auth.token;
      phone = _Device('phone', storage);
      tablet = _Device('tablet', storage);
      await phone.open();
      await tablet.open();
    });

    tearDownAll(() async {
      await phone.close();
      await tablet.close();
      if (storage.token != null) {
        await AccountRemoteDataSource(
          e2eApiClient(storage),
        ).deleteAccount(password: e2ePassword);
      }
    });

    test('offline exercise + finished workout are pushed', () async {
      final exercise = await phone.exercises.create(
        name: 'Sync przysiad $e2eRunId',
        muscles: const [MuscleGroup.quads, MuscleGroup.glutes],
        category: ExerciseCategory.compound,
        description: '',
      );
      await phone.exerciseSync.flush();
      final pushed = await phone.db.run(
        (db) => db.query(
          ExerciseDatabase.tableExercises,
          where: 'local_id = ?',
          whereArgs: [exercise.id],
        ),
      );
      expect(pushed.single['server_id'], isNotNull, reason: '${pushed.single}');
      expect(pushed.single['pending_op'], isNull);

      final plan = CustomTrainingPlan(
        name: 'Nogi $e2eRunId',
        exercises: [
          PlanExercise(
            exercise: exercise,
            sets: [
              ExerciseSet(weight: '100', reps: '5'),
              ExerciseSet(weight: '100', reps: '5'),
            ],
          ),
        ],
      );
      final started = await phone.sessions.startFromPlan(plan);
      sessionId = started.id;
      final done = started.copyWith(
        exercises: [
          started.exercises.single.copyWith(
            sets: [
              for (final set in started.exercises.single.sets)
                set.copyWith(
                  actualWeight: '100',
                  actualReps: '5',
                  completed: true,
                  completedAt: DateTime.now().toUtc(),
                ),
            ],
          ),
        ],
      );
      await phone.sessions.save(done);
      await phone.sessions.finish(sessionId);
      await phone.sessions.setSharedToProfile(sessionId, true);
      await phone.sessionSync.flush();

      final row = (await phone.sessionRows()).single;
      expect(row['pending_op'], isNull);
      expect(row['sync_error'], isNull);
      serverId = row['server_id'] as String;

      final post = await ApiFeedRepository(
        e2eApiClient(storage),
      ).getPost(serverId);
      expect(post.post.author.id, user.id);
      expect(post.post.completedSetsCount, 2);
      expect(post.post.totalVolumeKg, 1000);
      expect(post.exercises.single.exerciseName, exercise.name);
    });

    test('second device pulls the workout; history merges', () async {
      await tablet.sessionSync.pull();
      final pulled = await tablet.sessions.getById(sessionId);
      expect(pulled, isNotNull);
      expect(pulled!.serverId, serverId);
      expect(pulled.status, TrainingSessionStatus.completed);
      expect(pulled.sharedToProfile, isTrue);
      expect(pulled.exercises.single.sets.every((s) => s.completed), isTrue);

      final page = await tablet.history.getSessions();
      expect(page.items.map((i) => i.id), contains(serverId));
      final detail = await tablet.history.getSessionDetail(serverId);
      expect(detail.exercises.single.sets, hasLength(2));
    });

    test(
      'edit on tablet, delete on phone → 410 drops the edit, pull cleans',
      () async {
        final onTablet = (await tablet.sessions.loadForEdit(sessionId))!;
        await tablet.sessions.save(onTablet.copyWith(note: 'edytowane'));

        await phone.sessions.delete(sessionId);
        expect(await phone.localHistory.findById(sessionId), isNull);
        expect(
          await phone.localHistory.pendingDeletionIds(),
          contains(serverId),
        );
        await phone.sessionSync.flush();
        expect(await phone.sessionRows(), isEmpty);

        await tablet.sessionSync.flush();
        final tabletRows = await tablet.sessionRows();
        expect(
          tabletRows.where((r) => r['sync_error'] != null),
          isEmpty,
          reason: '410 session_deleted is not a sync error',
        );
        expect(await tablet.sessions.getById(sessionId), isNull);

        await tablet.sessionSync.pull();
        expect(await tablet.sessions.getById(sessionId), isNull);

        final server = await TrainingSessionRemoteDataSource(
          e2eApiClient(storage),
        ).history();
        expect(
          server.items.map((p) => p.session.serverId),
          isNot(contains(serverId)),
        );
      },
    );
  });
}
