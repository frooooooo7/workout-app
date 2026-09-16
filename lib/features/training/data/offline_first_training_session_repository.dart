import 'dart:async';
import 'dart:developer' as developer;

import '../../../core/network/api_client.dart';
import '../../../core/sync/sync_failure.dart';
import '../../library/data/exercise_database.dart';
import '../domain/models/custom_training_plan.dart';
import '../domain/models/training_session.dart';
import '../domain/repositories/training_session_repository.dart';
import '../domain/services/repeat_training_session.dart';
import 'sync/training_session_sync_engine.dart';
import 'training_history_local_cache.dart';
import 'training_session_local_mapper.dart';
import 'training_session_remote_data_source.dart';

export '../domain/repositories/training_session_repository.dart'
    show TrainingSessionDeletedException;

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
    TrainingSessionRemoteDataSource? remote,
  }) : _localDb = localDb,
       _sync = syncEngine,
       _remote = remote,
       _historyCache = TrainingHistoryLocalCache(localDb);

  final ExerciseDatabase _localDb;
  final TrainingSessionSyncEngine _sync;
  final TrainingSessionRemoteDataSource? _remote;
  final TrainingHistoryLocalCache _historyCache;

  static const _pendingDelete = 'delete';

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

  /// Wiersz po `local_id`, potem po `server_id`. Nagrobki (`pending_op =
  /// 'delete'`) zwracane są tylko z [includePendingDelete].
  Future<Map<String, dynamic>?> _findRow(
    String id, {
    bool includePendingDelete = false,
  }) {
    return _localDb.run((db) async {
      for (final column in const ['local_id', 'server_id']) {
        final rows = await db.query(
          ExerciseDatabase.tableTrainingSessions,
          where: '$column = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (rows.isEmpty) continue;
        final row = rows.first;
        if (!includePendingDelete && row['pending_op'] == _pendingDelete) {
          return null;
        }
        return row;
      }
      return null;
    });
  }

  Future<bool> _isPendingDelete(String id) async {
    final row = await _findRow(id, includePendingDelete: true);
    return row != null && row['pending_op'] == _pendingDelete;
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
  Future<TrainingSession?> getById(String sessionId) async {
    final row = await _findRow(sessionId);
    if (row == null) return null;
    return _localDb.run((db) => TrainingSessionLocalMapper.fromDb(db, row));
  }

  @override
  Future<TrainingSession?> getActive() async {
    return _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingSessions,
        where: "status = ? AND (pending_op IS NULL OR pending_op <> 'delete')",
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
  Future<TrainingSession> startFromSession(TrainingSession source) async {
    final active = await getActive();
    if (active != null) throw ActiveTrainingSessionException(active);

    late TrainingSession session;
    await _localDb.run((db) async {
      // Powiązanie z planem tylko, gdy plan nadal istnieje (i nie czeka na
      // usunięcie) — inaczej zostaje sama nazwa.
      final planIds = {
        ?source.planLocalId,
        ?source.planServerId,
      }.where((id) => id.isNotEmpty).toList();
      String? planLocalId;
      String? planServerId;
      if (planIds.isNotEmpty) {
        final placeholders = List.filled(planIds.length, '?').join(', ');
        final planRows = await db.query(
          ExerciseDatabase.tableTrainingPlans,
          columns: ['local_id', 'server_id'],
          where:
              '(local_id IN ($placeholders) OR server_id IN ($placeholders)) '
              "AND is_deleted = 0 AND (pending_op IS NULL OR pending_op <> 'delete')",
          whereArgs: [...planIds, ...planIds],
          limit: 1,
        );
        if (planRows.isNotEmpty) {
          planLocalId = planRows.first['local_id'] as String;
          planServerId = planRows.first['server_id'] as String?;
        }
      }
      session = buildRepeatedSession(
        source,
        planLocalId: planLocalId,
        planServerId: planServerId,
      );
      await TrainingSessionLocalMapper.upsert(
        db,
        session,
        pendingOp: session.exercises.isEmpty ? null : 'create',
      );
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
      final storedPending = rows.isEmpty
          ? null
          : rows.first['pending_op'] as String?;
      if (storedPending == _pendingDelete) {
        throw TrainingSessionDeletedException(session.id);
      }
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
    return _updateSession(
      row,
      (current) => current.copyWith(
        status: TrainingSessionStatus.completed,
        finishedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<TrainingSession> setSharedToProfile(
    String sessionId,
    bool shared,
  ) async {
    final row = await _findRow(sessionId);
    if (row != null) {
      return _updateSession(
        row,
        (current) => current.copyWith(sharedToProfile: shared),
      );
    }
    if (await _isPendingDelete(sessionId)) {
      throw TrainingSessionDeletedException(sessionId);
    }
    final remote = _remote;
    if (remote == null) throw StateError('Training session not found');
    try {
      return await remote.setSharedToProfile(sessionId, shared);
    } on ApiException catch (e) {
      if (!isGoneFailure(e)) rethrow;
      await _historyCache.removeSessions({sessionId});
      throw TrainingSessionDeletedException(sessionId);
    }
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
        snapshot = current.copyWith(status: TrainingSessionStatus.cancelled);
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

  @override
  Future<TrainingSession?> loadForEdit(String sessionId) async {
    final local = await getById(sessionId);
    if (local != null) return local;
    if (await _isPendingDelete(sessionId)) return null;
    if (_sync.isStopped) return null;

    // Sesja z innego urządzenia, której pull jeszcze nie ściągnął.
    try {
      await _sync.pull();
    } catch (_) {
      /* offline — spróbujemy wyszukać niżej */
    }
    final pulled = await getById(sessionId);
    if (pulled != null) return pulled;

    // Starsza niż znacznik przyrostowego pobierania — szukamy w pełnej
    // historii.
    try {
      if (!await _sync.fetchFromServer(sessionId)) return null;
    } catch (_) {
      return null;
    }
    return getById(sessionId);
  }

  @override
  Future<void> delete(String sessionId) async {
    final cacheIds = <String>{sessionId};
    var queued = false;
    await _localDb.run((db) async {
      await db.transaction((txn) async {
        Map<String, Object?>? row;
        for (final column in const ['local_id', 'server_id']) {
          final rows = await txn.query(
            ExerciseDatabase.tableTrainingSessions,
            where: '$column = ?',
            whereArgs: [sessionId],
            limit: 1,
          );
          if (rows.isNotEmpty) {
            row = rows.first;
            break;
          }
        }
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;

        if (row == null) {
          // Znana tylko z historii serwera (np. inne urządzenie): minimalny
          // nagrobek, który ukryje ją w historii i wyśle DELETE.
          await txn.insert(ExerciseDatabase.tableTrainingSessions, {
            'local_id': sessionId,
            'server_id': sessionId,
            'plan_name': '',
            'status': TrainingSessionStatus.completed.name,
            'started_at': 0,
            'shared_to_profile': 0,
            'created_at': now,
            'updated_at': now,
            'pending_op': _pendingDelete,
          });
          queued = true;
          return;
        }

        final localId = row['local_id'] as String;
        final serverId = row['server_id'] as String?;
        final pending = row['pending_op'] as String?;
        cacheIds
          ..add(localId)
          ..addAll([?serverId]);
        if (pending == _pendingDelete) {
          queued = row['sync_error'] == null;
          return;
        }

        if (serverId == null && pending == null) {
          // Nigdy nie trafiła do kolejki (pusta sesja) — serwer jej nie zna.
          await TrainingSessionLocalMapper.deleteSession(txn, localId);
          return;
        }

        // Ćwiczenia i serie znikają od razu; wiersz sesji zostaje jako
        // nagrobek do wysłania (`DELETE /:id` albo po clientId).
        await TrainingSessionLocalMapper.deleteChildren(txn, localId);
        await txn.update(
          ExerciseDatabase.tableTrainingSessions,
          {
            'pending_op': _pendingDelete,
            'sync_error': null,
            'updated_at': now,
          },
          where: 'local_id = ?',
          whereArgs: [localId],
        );
        queued = true;
      });
    });
    await _historyCache.removeSessions(cacheIds);
    if (queued) _scheduleSync();
  }

  /// Odczytuje sesję z [row], nakłada [mutate] i zapisuje ją z właściwym
  /// `pending_op`, a potem planuje synchronizację.
  Future<TrainingSession> _updateSession(
    Map<String, dynamic> row,
    TrainingSession Function(TrainingSession current) mutate,
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

      updated = mutate(current).copyWith(pendingOp: nextPending);

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
