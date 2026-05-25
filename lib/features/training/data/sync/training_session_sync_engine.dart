import 'dart:async';
import 'dart:developer' as developer;

import '../../../../core/network/api_client.dart';
import '../../../library/data/exercise_database.dart';
import '../../domain/models/training_session.dart';
import '../training_session_local_mapper.dart';
import '../training_session_remote_data_source.dart';

class TrainingSessionSyncEngine {
  TrainingSessionSyncEngine({
    required TrainingSessionRemoteDataSource remote,
    required ExerciseDatabase localDb,
  }) : _remote = remote,
       _localDb = localDb;

  final TrainingSessionRemoteDataSource _remote;
  final ExerciseDatabase _localDb;

  bool _stopped = false;
  Future<void> _queue = Future<void>.value();

  bool get isStopped => _stopped;

  void stop() => _stopped = true;

  void scheduleBootstrap() {
    unawaited(
      _bootstrap().catchError((_) {
        /* bootstrap sync is best-effort */
      }),
    );
  }

  Future<void> _bootstrap() async {
    try {
      await flush();
    } catch (_) {
      /* offline */
    }
  }

  Future<void> _runExclusive(Future<void> Function() body) {
    final done = Completer<void>();
    _queue = _queue.then((_) async {
      try {
        await body();
        if (!done.isCompleted) done.complete();
      } catch (e, st) {
        if (!done.isCompleted) done.completeError(e, st);
      }
    });
    return done.future;
  }

  Future<void> flush() => _runExclusive(_flushImpl);

  Future<void> _logFailure(String localId, String op, ApiException e) async {
    await _localDb.run((db) async {
      await db.insert(ExerciseDatabase.tableOutboxLog, {
        'local_id': localId,
        'op': op,
        'attempts': 1,
        'last_error': e.message,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  Future<Map<String, String?>> _exerciseServerIdsByLocalId(
    TrainingSession session,
  ) {
    return _localDb.run((db) async {
      final result = <String, String?>{};
      final exerciseIds = session.exercises
          .map((exercise) => exercise.exerciseId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      if (exerciseIds.isEmpty) return result;

      final placeholders = List.filled(exerciseIds.length, '?').join(', ');
      final rows = await db.query(
        ExerciseDatabase.tableExercises,
        columns: ['local_id', 'server_id'],
        where: 'local_id IN ($placeholders) OR server_id IN ($placeholders)',
        whereArgs: [...exerciseIds, ...exerciseIds],
      );
      final serverByKnownId = <String, String?>{};
      for (final row in rows) {
        final localId = row['local_id'] as String;
        final serverId = row['server_id'] as String?;
        serverByKnownId[localId] = serverId;
        if (serverId != null) serverByKnownId[serverId] = serverId;
      }
      for (final id in exerciseIds) {
        result[id] = serverByKnownId[id];
      }
      return result;
    });
  }

  Future<void> _flushImpl() async {
    if (_stopped) return;
    try {
      final rows = await _localDb.run((db) {
        return db.query(
          ExerciseDatabase.tableTrainingSessions,
          where: 'pending_op IS NOT NULL',
          orderBy:
              "CASE pending_op WHEN 'create' THEN 0 WHEN 'update' THEN 1 ELSE 2 END",
        );
      });
      for (final row in rows) {
        if (_stopped) return;
        final localId = row['local_id'] as String;
        final op = row['pending_op'] as String?;
        try {
          final session = await _localDb.run((db) {
            return TrainingSessionLocalMapper.fromDb(db, row);
          });
          if (session == null) continue;
          if (session.exercises.isEmpty) {
            developer.log(
              'Skipping empty session $localId',
              name: 'TrainingSessionSyncEngine',
            );
            continue;
          }
          final exerciseMap = await _exerciseServerIdsByLocalId(session);
          final serverId = row['server_id'] as String?;
          final saved = op == 'create' || serverId == null
              ? await _remote.create(
                  session,
                  exerciseServerIdsByLocalId: exerciseMap,
                )
              : await _remote.update(
                  serverId,
                  session,
                  exerciseServerIdsByLocalId: exerciseMap,
                );
          await _storePulled(
            saved,
            localIdOverride: localId,
            expectedUpdatedAt: row['updated_at'] as int?,
            op: op,
          );
        } on ApiException catch (e) {
          await _logFailure(localId, '${op}_training_session', e);
        }
      }
    } on StateError {
      /* DB closing */
    }
  }

  Future<void> _storePulled(
    TrainingSession session, {
    String? localIdOverride,
    int? expectedUpdatedAt,
    String? op,
  }) async {
    await _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingSessions,
        where: localIdOverride != null ? 'local_id = ?' : 'server_id = ?',
        whereArgs: [localIdOverride ?? session.serverId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final row = rows.first;
        final pending = row['pending_op'] as String?;
        final updatedAt = row['updated_at'] as int?;
        if (expectedUpdatedAt != null && updatedAt != expectedUpdatedAt) {
          final updates = <String, Object?>{'server_id': session.serverId};
          if (op == 'create') {
            updates['pending_op'] = 'update';
          } else if (pending != null) {
            updates['pending_op'] = pending;
          }
          await db.update(
            ExerciseDatabase.tableTrainingSessions,
            updates,
            where: 'local_id = ?',
            whereArgs: [row['local_id']],
          );
          return;
        }
      }
      final localId =
          localIdOverride ??
          (rows.isEmpty ? session.id : rows.first['local_id'] as String);
      await TrainingSessionLocalMapper.upsert(
        db,
        session.copyWith(id: localId, serverId: session.serverId),
        serverId: session.serverId,
        clearPendingOp: true,
      );
    });
  }
}
