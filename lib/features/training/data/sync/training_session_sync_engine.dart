import 'dart:async';

import '../../../../core/network/api_client.dart';
import '../../../../core/sync/sync_engine_base.dart';
import '../../../../core/sync/sync_failure.dart';
import '../../../library/data/exercise_database.dart';
import '../../domain/models/training_session.dart';
import '../training_session_local_mapper.dart';
import '../training_session_remote_data_source.dart';

class TrainingSessionSyncEngine extends SyncEngineBase {
  TrainingSessionSyncEngine({
    required TrainingSessionRemoteDataSource remote,
    required ExerciseDatabase localDb,
    super.onDataChanged,
  }) : _remote = remote,
       _localDb = localDb;

  final TrainingSessionRemoteDataSource _remote;
  final ExerciseDatabase _localDb;

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

  /// Wysyła oczekujące sesje. Kolejne wywołania w trakcie treningu (zapis
  /// co serię) zlewają się w jedną próbę zamiast budować kolejkę.
  Future<void> flush() => runCoalesced('flush', _flushImpl);

  Future<void> _handleFailure(
    String localId,
    String op,
    ApiException error,
  ) async {
    await _localDb.recordSyncAttemptFailure(
      localId: localId,
      op: op,
      message: error.message,
    );
    if (registerFailure(error) == SyncFailureKind.permanent) {
      await _localDb.markSyncRejected(
        table: ExerciseDatabase.tableTrainingSessions,
        localId: localId,
        reason: error.message,
      );
    }
  }

  Future<Map<String, String?>> _exerciseServerIdsByLocalId(
    TrainingSession session,
  ) {
    return _localDb.run((db) async {
      final result = <String, String?>{};
      final exerciseIds = _exerciseIds(session);
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

  List<String> _exerciseIds(TrainingSession session) => session.exercises
      .map((exercise) => exercise.exerciseId)
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  /// Ćwiczenie dodane offline, które samo czeka jeszcze na wysłanie — lepiej
  /// wstrzymać sesję o jeden cykl, niż zapisać ją bez powiązania z ćwiczeniem.
  Future<bool> _waitsForExercises(TrainingSession session) async {
    final ids = _exerciseIds(session);
    if (ids.isEmpty) return false;
    return _localDb.run((db) async {
      final placeholders = List.filled(ids.length, '?').join(', ');
      final rows = await db.rawQuery(
        'SELECT 1 FROM ${ExerciseDatabase.tableExercises} '
        'WHERE local_id IN ($placeholders) AND server_id IS NULL '
        "AND pending_op = 'create' AND sync_error IS NULL LIMIT 1",
        ids,
      );
      return rows.isNotEmpty;
    });
  }

  Future<List<Map<String, dynamic>>?> _pendingRows() async {
    try {
      return await _localDb.run(
        (db) => db.query(
          ExerciseDatabase.tableTrainingSessions,
          columns: ['local_id'],
          where: 'pending_op IS NOT NULL AND sync_error IS NULL',
          orderBy:
              "CASE pending_op WHEN 'create' THEN 0 WHEN 'update' THEN 1 ELSE 2 END",
        ),
      );
    } on StateError {
      return null; /* DB closing */
    }
  }

  Future<void> _flushImpl() async {
    if (isStopped) return;
    final rows = await _pendingRows();
    if (rows == null || rows.isEmpty) return;

    var finishedSessionSynced = false;
    for (final row in rows) {
      if (isStopped) return;
      final localId = row['local_id'] as String;
      try {
        final saved = await _flushSession(localId);
        if (saved != null && saved.status != TrainingSessionStatus.active) {
          finishedSessionSynced = true;
        }
      } catch (error, stackTrace) {
        if (isStopped) return;
        // Jeden uszkodzony wiersz nie może zablokować wysyłki pozostałych.
        logUnexpected(
          'Training session $localId sync failed',
          error,
          stackTrace,
        );
      }
    }
    // Historia interesuje się tylko zakończonymi sesjami — zapis w trakcie
    // treningu nie powinien co chwilę odświeżać list.
    if (finishedSessionSynced) notifyDataChanged();
  }

  /// Zwraca sesję zapisaną na serwerze albo `null`, gdy nic nie wysłano.
  Future<TrainingSession?> _flushSession(String localId) async {
    // Świeży odczyt — trening mógł zostać zapisany od zapytania o kolejkę.
    final payload = await _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingSessions,
        where: 'local_id = ?',
        whereArgs: [localId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      final op = row['pending_op'] as String?;
      if (op == null) return null;
      final session = await TrainingSessionLocalMapper.fromDb(db, row);
      if (session == null) return null;
      return _SessionPayload(
        op: op,
        serverId: row['server_id'] as String?,
        updatedAt: row['updated_at'] as int?,
        session: session,
      );
    });
    if (payload == null) return null;

    final session = payload.session;
    if (session.exercises.isEmpty) return null;
    if (await _waitsForExercises(session)) return null;

    final exerciseMap = await _exerciseServerIdsByLocalId(session);
    final saved = await _send(
      localId: localId,
      payload: payload,
      exerciseMap: exerciseMap,
    );
    if (saved == null) return null;

    await _storePulled(
      saved,
      localIdOverride: localId,
      expectedUpdatedAt: payload.updatedAt,
      op: payload.op,
    );
    await _localDb.clearSyncAttempts(localId);
    return saved;
  }

  Future<TrainingSession?> _send({
    required String localId,
    required _SessionPayload payload,
    required Map<String, String?> exerciseMap,
  }) async {
    final serverId = payload.serverId;
    try {
      if (payload.op == 'create' || serverId == null) {
        return await _remote.create(
          payload.session,
          exerciseServerIdsByLocalId: exerciseMap,
        );
      }
      try {
        return await _remote.update(
          serverId,
          payload.session,
          exerciseServerIdsByLocalId: exerciseMap,
        );
      } on ApiException catch (e) {
        if (e.statusCode != 404) rethrow;
        // Sesji nie ma już na serwerze — odtwórz ją (upsert po clientId).
        return await _remote.create(
          payload.session,
          exerciseServerIdsByLocalId: exerciseMap,
        );
      }
    } on ApiException catch (e) {
      await _handleFailure(localId, '${payload.op}_training_session', e);
      return null;
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
          // Zapisane w trakcie żądania — zachowaj lokalną wersję do wysłania.
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

class _SessionPayload {
  const _SessionPayload({
    required this.op,
    required this.serverId,
    required this.updatedAt,
    required this.session,
  });

  final String op;
  final String? serverId;
  final int? updatedAt;
  final TrainingSession session;
}
