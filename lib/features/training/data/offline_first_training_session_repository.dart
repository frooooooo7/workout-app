import 'dart:async';
import 'dart:developer' as developer;

import '../../library/data/exercise_database.dart';
import '../domain/models/custom_training_plan.dart';
import '../domain/models/training_session.dart';
import '../domain/repositories/training_session_repository.dart';
import 'sync/training_session_sync_engine.dart';
import 'training_session_local_mapper.dart';

class ActiveTrainingSessionException implements Exception {
  const ActiveTrainingSessionException(this.session);

  final TrainingSession session;

  @override
  String toString() =>
      'ActiveTrainingSessionException(sessionId: ${session.id}, plan: ${session.planName})';
}

class OfflineFirstTrainingSessionRepository
    implements TrainingSessionRepository {
  OfflineFirstTrainingSessionRepository({
    required ExerciseDatabase localDb,
    required TrainingSessionSyncEngine syncEngine,
  }) : _localDb = localDb,
       _sync = syncEngine;

  final ExerciseDatabase _localDb;
  final TrainingSessionSyncEngine _sync;

  void _scheduleSync() {
    if (_sync.isStopped) return;
    unawaited(
      _sync.flush().catchError((Object error, StackTrace stackTrace) {
        developer.log(
          'Training session sync failed',
          name: 'OfflineFirstTrainingSessionRepository',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  Future<Map<String, dynamic>?> _findRow(String id) {
    return _localDb.run((db) async {
      final byLocal = await db.query(
        ExerciseDatabase.tableTrainingSessions,
        where: 'local_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (byLocal.isNotEmpty) return byLocal.first;
      final byServer = await db.query(
        ExerciseDatabase.tableTrainingSessions,
        where: 'server_id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (byServer.isNotEmpty) return byServer.first;
      return null;
    });
  }

  /// Stored [pending_op] from DB influences in-flight creates; exercises and
  /// [serverId] determine whether local-only sessions defer sync entirely.
  static String? nextPendingAfterWrite({
    required String? serverId,
    required List<TrainingSessionExercise> exercises,
    required String? storedPendingOp,
  }) {
    if (serverId == null && exercises.isEmpty) return null;
    if (serverId != null) {
      return storedPendingOp == 'create' ? 'create' : 'update';
    }
    return 'create';
  }

  @override
  Future<TrainingSession?> getActive() async {
    return _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingSessions,
        where: 'status = ?',
        whereArgs: [TrainingSessionStatus.active.name],
        orderBy: 'started_at DESC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return TrainingSessionLocalMapper.fromDb(db, rows.first);
    });
  }

  @override
  Future<TrainingSession> startFromPlan(CustomTrainingPlan plan) async {
    final active = await getActive();
    if (active != null) throw ActiveTrainingSessionException(active);

    late TrainingSession session;
    await _localDb.run((db) async {
      final planRows = await db.query(
        ExerciseDatabase.tableTrainingPlans,
        columns: ['server_id'],
        where: 'local_id = ? OR server_id = ?',
        whereArgs: [plan.id, plan.id],
        limit: 1,
      );
      final planServerId = planRows.isEmpty
          ? null
          : planRows.first['server_id'] as String?;
      session = TrainingSession.fromPlan(plan, planServerId: planServerId);
      await TrainingSessionLocalMapper.upsert(db, session, pendingOp: 'create');
    });
    _scheduleSync();
    return session;
  }

  @override
  Future<TrainingSession> startCustom({
    String planName = TrainingSession.defaultCustomName,
  }) async {
    final active = await getActive();
    if (active != null) throw ActiveTrainingSessionException(active);

    late TrainingSession session;
    await _localDb.run((db) async {
      session = TrainingSession.custom(planName: planName);
      await TrainingSessionLocalMapper.upsert(db, session, pendingOp: null);
    });
    return session;
  }

  @override
  Future<TrainingSession> save(TrainingSession session) async {
    TrainingSession saved = session;
    await _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingSessions,
        where: 'local_id = ?',
        whereArgs: [session.id],
        limit: 1,
      );
      final storedPending =
          rows.isEmpty ? null : rows.first['pending_op'] as String?;
      final serverIdInDb = rows.isEmpty
          ? null
          : rows.first['server_id'] as String?;
      final effectiveServerId = serverIdInDb ?? session.serverId;

      final nextPending = nextPendingAfterWrite(
        serverId: effectiveServerId,
        exercises: session.exercises,
        storedPendingOp: storedPending,
      );
      saved = session.copyWith(pendingOp: nextPending);
      await TrainingSessionLocalMapper.upsert(
        db,
        saved,
        serverId: rows.isEmpty
            ? session.serverId
            : rows.first['server_id'] as String?,
        pendingOp: nextPending,
      );
    });
    _scheduleSync();
    return saved;
  }

  @override
  Future<TrainingSession> finish(String sessionId) async {
    final row = await _findRow(sessionId);
    if (row == null) throw StateError('Training session not found');
    return _updateActiveStatus(row, TrainingSessionStatus.completed);
  }

  @override
  Future<TrainingSession> cancel(String sessionId) async {
    final row = await _findRow(sessionId);
    if (row == null) throw StateError('Training session not found');

    late TrainingSession snapshot;
    var scheduleSyncAfter = true;

    await _localDb.run((db) async {
      final current = await TrainingSessionLocalMapper.fromDb(db, row);
      if (current == null) throw StateError('Training session not found');

      final serverId = row['server_id'] as String?;
      if (serverId == null && current.exercises.isEmpty) {
        snapshot =
            current.copyWith(status: TrainingSessionStatus.cancelled);
        await TrainingSessionLocalMapper.deleteSession(db, current.id);
        scheduleSyncAfter = false;
        return;
      }

      final pending = row['pending_op'] as String?;
      final nextPending = nextPendingAfterWrite(
        serverId: serverId,
        exercises: current.exercises,
        storedPendingOp: pending,
      );

      snapshot = current.copyWith(
        status: TrainingSessionStatus.cancelled,
        pendingOp: nextPending,
      );

      await TrainingSessionLocalMapper.upsert(
        db,
        snapshot,
        serverId: row['server_id'] as String?,
        pendingOp: nextPending,
      );
    });

    if (scheduleSyncAfter) _scheduleSync();
    return snapshot;
  }

  Future<TrainingSession> _updateActiveStatus(
    Map<String, dynamic> row,
    TrainingSessionStatus status,
  ) async {
    late TrainingSession updated;
    await _localDb.run((db) async {
      final current = await TrainingSessionLocalMapper.fromDb(db, row);
      if (current == null) throw StateError('Training session not found');

      final pending = row['pending_op'] as String?;
      final serverId = row['server_id'] as String?;

      final nextPending = nextPendingAfterWrite(
        serverId: serverId,
        exercises: current.exercises,
        storedPendingOp: pending,
      );

      updated = current.copyWith(
        status: status,
        finishedAt: status == TrainingSessionStatus.completed
            ? DateTime.now().toUtc()
            : current.finishedAt,
        pendingOp: nextPending,
      );

      await TrainingSessionLocalMapper.upsert(
        db,
        updated,
        serverId: row['server_id'] as String?,
        pendingOp: nextPending,
      );
    });
    _scheduleSync();
    return updated;
  }
}
