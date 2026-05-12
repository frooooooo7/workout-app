import 'dart:async';

import '../../library/data/exercise_database.dart';
import '../domain/models/custom_training_plan.dart';
import '../domain/models/training_session.dart';
import '../domain/repositories/training_session_repository.dart';
import 'sync/training_session_sync_engine.dart';
import 'training_session_local_mapper.dart';

class ActiveTrainingSessionException implements Exception {
  const ActiveTrainingSessionException(this.session);

  final TrainingSession session;
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
      _sync.flush().catchError((_) {
        /* background sync must never break the UI event loop */
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
  Future<TrainingSession> save(TrainingSession session) async {
    TrainingSession saved = session;
    await _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingSessions,
        where: 'local_id = ?',
        whereArgs: [session.id],
        limit: 1,
      );
      final pending = rows.isEmpty ? null : rows.first['pending_op'] as String?;
      final nextPending = pending == 'create' ? 'create' : 'update';
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
    return _removeActive(row);
  }

  @override
  Future<TrainingSession> cancel(String sessionId) async {
    final row = await _findRow(sessionId);
    if (row == null) throw StateError('Training session not found');
    return _removeActive(row);
  }

  Future<TrainingSession> _removeActive(Map<String, dynamic> row) async {
    late TrainingSession removed;
    await _localDb.run((db) async {
      final current = await TrainingSessionLocalMapper.fromDb(db, row);
      if (current == null) throw StateError('Training session not found');
      removed = current;
      await db.delete(
        ExerciseDatabase.tableTrainingSessions,
        where: 'local_id = ?',
        whereArgs: [row['local_id']],
      );
    });
    return removed;
  }
}
