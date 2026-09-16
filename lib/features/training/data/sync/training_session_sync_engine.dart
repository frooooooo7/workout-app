import 'dart:async';

import '../../../../core/network/api_client.dart';
import '../../../../core/sync/sync_engine_base.dart';
import '../../../../core/sync/sync_failure.dart';
import '../../../library/data/exercise_database.dart';
import '../../domain/models/training_session.dart';
import '../training_history_local_cache.dart';
import '../training_session_local_mapper.dart';
import '../training_session_remote_data_source.dart';

/// Synchronizacja sesji treningowych.
///
/// **Wysyłka** (`flush`): `create` / `update` → `POST` / `PUT`, `delete` →
/// `DELETE /training-sessions/:id` (albo `by-client-id`, gdy serwer nie zna
/// jeszcze id). Usunięcie zostawia lokalnie sam wiersz sesji z
/// `pending_op = 'delete'` (bez ćwiczeń i serii) — ukryty w historii
/// i statystykach, dopóki serwer nie potwierdzi usunięcia.
///
/// **`410 session_deleted`** przy zapisie oznacza, że sesję usunięto (np. na
/// innym urządzeniu): lokalna kopia znika, bez oznaczania błędu.
///
/// **Pobieranie** (`pull`): `GET /training-sessions/history?updatedSince=`,
/// strona po stronie. Pierwsze pobranie (bez znacznika) ściąga całą historię
/// i usuwa lokalne zsynchronizowane sesje, których serwer już nie ma. Kolejne
/// są przyrostowe i stosują `deleted[]`. Znacznik to największe `updatedAt` /
/// `deletedAt` z odpowiedzi (zegar serwera, nie urządzenia), a zapytanie
/// cofa się o [pullOverlap].
class TrainingSessionSyncEngine extends SyncEngineBase {
  TrainingSessionSyncEngine({
    required TrainingSessionRemoteDataSource remote,
    required ExerciseDatabase localDb,
    super.onDataChanged,
    this.pullPageSize = 100,
  }) : _remote = remote,
       _localDb = localDb,
       _historyCache = TrainingHistoryLocalCache(localDb);

  final TrainingSessionRemoteDataSource _remote;
  final ExerciseDatabase _localDb;
  final TrainingHistoryLocalCache _historyCache;
  final int pullPageSize;

  /// Klucz znacznika przyrostowego pobierania w `sync_state`.
  static const pullHighWaterMarkKey = 'training_sessions.pull_high_water_mark';

  /// Zapisy z tym samym `updated_at` mogą zatwierdzić się w innej kolejności
  /// niż ich znaczniki czasu — zapytanie zaczyna trochę wcześniej. Sesje już
  /// znane w tej wersji są pomijane (`server_updated_at`).
  static const pullOverlap = Duration(seconds: 30);

  /// Ochrona przed zapętleniem przy wadliwym kursorze.
  static const _maxPullPages = 500;

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

  /// Pobiera zakończone sesje i usunięcia z serwera.
  Future<void> pull() => runCoalesced('pull', _pullImpl);

  /// Jak [pull], ale najwyżej raz na [maxAge] (odczyty ekranów).
  Future<void> pullIfDue({
    Duration maxAge = SyncEngineBase.defaultPullMaxAge,
  }) {
    return runCoalesced('pull-if-due', () async {
      if (isPullDue(maxAge)) await _pullImpl();
    });
  }

  /// Szuka sesji o id serwerowym lub `clientId` [sessionId] w pełnej historii
  /// na serwerze i zapisuje ją lokalnie. Zwraca `true`, gdy ją znalazł.
  Future<bool> fetchFromServer(String sessionId) async {
    var found = false;
    await runExclusive(() async {
      if (isStopped) return;
      try {
        String? cursor;
        for (var page = 0; page < _maxPullPages; page++) {
          final result = await _remote.history(
            limit: pullPageSize,
            cursor: cursor,
          );
          if (isStopped) return;
          for (final item in result.items) {
            final session = item.session;
            if (session.serverId == sessionId || session.id == sessionId) {
              await _storeFromHistory(item);
              found = true;
              return;
            }
          }
          cursor = result.hasMore ? result.nextCursor : null;
          if (cursor == null) return;
        }
      } on ApiException catch (e) {
        registerFailure(e);
      } on StateError {
        /* DB closing */
      }
    });
    if (found) notifyDataChanged();
    return found;
  }

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

  // ── Flush ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>?> _pendingRows() async {
    try {
      return await _localDb.run(
        (db) => db.query(
          ExerciseDatabase.tableTrainingSessions,
          columns: ['local_id', 'server_id', 'pending_op'],
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

    final networkMark = networkFailureMark;
    var changed = false;
    for (final row in rows) {
      if (isStopped) return;
      final localId = row['local_id'] as String;
      try {
        final outcome = row['pending_op'] == 'delete'
            ? await _flushDelete(localId, row['server_id'] as String?)
            : await _flushSession(localId);
        if (outcome == _FlushOutcome.changedHistory) changed = true;
      } catch (error, stackTrace) {
        if (isStopped) return;
        // Jeden uszkodzony wiersz nie może zablokować wysyłki pozostałych.
        logUnexpected(
          'Training session $localId sync failed',
          error,
          stackTrace,
        );
      }
      if (networkFailedSince(networkMark)) break;
    }
    // Historia interesuje się tylko zakończonymi sesjami — zapis w trakcie
    // treningu nie powinien co chwilę odświeżać list.
    if (changed) notifyDataChanged();
  }

  /// `400` (niepoprawne id) / `404` (nigdy nie była nasza) / `410` — na
  /// serwerze tej sesji nie ma, więc cel usunięcia jest osiągnięty.
  static bool _deleteAlreadyDone(ApiException error) {
    final status = error.statusCode;
    return status == 400 || status == 404 || status == 410;
  }

  Future<_FlushOutcome> _flushDelete(String localId, String? serverId) async {
    try {
      if (serverId != null) {
        try {
          await _remote.delete(serverId);
        } on ApiException catch (e) {
          if (!_deleteAlreadyDone(e)) rethrow;
          // Nieaktualne server_id — nagrobek po clientId zatrzyma też zapis,
          // który mógł utknąć w drodze.
          if (e.statusCode == 404 && localId != serverId) {
            await _deleteByClientId(localId);
          }
        }
      } else {
        // Serwer nie zna id — create mógł już dotrzeć (albo wciąż czeka
        // gdzieś w kolejce); nagrobek po clientId zabija oba przypadki.
        await _deleteByClientId(localId);
      }
    } on ApiException catch (e) {
      await _handleFailure(localId, 'delete_training_session', e);
      return _FlushOutcome.none;
    }

    await _removeLocalSessions({localId});
    return _FlushOutcome.changedHistory;
  }

  Future<void> _deleteByClientId(String clientId) async {
    try {
      await _remote.deleteByClientId(clientId);
    } on ApiException catch (e) {
      if (!_deleteAlreadyDone(e)) rethrow;
    }
  }

  Future<_FlushOutcome> _flushSession(String localId) async {
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
      if (op == null || op == 'delete') return null;
      final session = await TrainingSessionLocalMapper.fromDb(db, row);
      if (session == null) return null;
      return _SessionPayload(
        op: op,
        serverId: row['server_id'] as String?,
        updatedAt: row['updated_at'] as int?,
        session: session,
      );
    });
    if (payload == null) return _FlushOutcome.none;

    final session = payload.session;
    if (session.exercises.isEmpty) return _FlushOutcome.none;
    if (await _waitsForExercises(session)) return _FlushOutcome.none;

    final exerciseMap = await _exerciseServerIdsByLocalId(session);
    final _SendResult result;
    try {
      result = await _send(payload: payload, exerciseMap: exerciseMap);
    } on ApiException catch (e) {
      if (isGoneFailure(e)) {
        // Usunięta na serwerze (np. na innym urządzeniu) — nie ponawiamy
        // i nie pokazujemy błędu; znika też lokalnie.
        await _removeLocalSessions({localId});
        return _FlushOutcome.changedHistory;
      }
      await _handleFailure(localId, '${payload.op}_training_session', e);
      return _FlushOutcome.none;
    }

    final saved = result.session;
    await _storeSent(
      saved,
      localId: localId,
      expectedUpdatedAt: payload.updatedAt,
      op: payload.op,
    );
    await _localDb.clearSyncAttempts(localId);
    return saved.status == TrainingSessionStatus.active
        ? _FlushOutcome.none
        : _FlushOutcome.changedHistory;
  }

  Future<_SendResult> _send({
    required _SessionPayload payload,
    required Map<String, String?> exerciseMap,
  }) async {
    final serverId = payload.serverId;
    if (payload.op == 'create' || serverId == null) {
      return _SendResult(
        await _remote.create(
          payload.session,
          exerciseServerIdsByLocalId: exerciseMap,
        ),
      );
    }
    try {
      return _SendResult(
        await _remote.update(
          serverId,
          payload.session,
          exerciseServerIdsByLocalId: exerciseMap,
        ),
      );
    } on ApiException catch (e) {
      // 410 nie może spaść do POST — sesja jest usunięta, nie zgubiona.
      if (e.statusCode != 404) rethrow;
      // Sesji nie ma już na serwerze — odtwórz ją (upsert po clientId).
      return _SendResult(
        await _remote.create(
          payload.session,
          exerciseServerIdsByLocalId: exerciseMap,
        ),
      );
    }
  }

  /// Zapisuje odpowiedź serwera na wysyłkę wiersza [localId].
  Future<void> _storeSent(
    TrainingSession session, {
    required String localId,
    int? expectedUpdatedAt,
    String? op,
  }) async {
    await _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingSessions,
        where: 'local_id = ?',
        whereArgs: [localId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final row = rows.first;
        final pending = row['pending_op'] as String?;
        final updatedAt = row['updated_at'] as int?;
        if (expectedUpdatedAt != null && updatedAt != expectedUpdatedAt) {
          // Zapisane w trakcie żądania — zachowaj lokalną wersję do wysłania.
          // Usunięcie w trakcie zostaje usunięciem (teraz już z server_id).
          final updates = <String, Object?>{'server_id': session.serverId};
          if (pending == 'delete') {
            updates['pending_op'] = 'delete';
          } else if (op == 'create') {
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
      await TrainingSessionLocalMapper.upsert(
        db,
        session.copyWith(id: localId, serverId: session.serverId),
        serverId: session.serverId,
        clearPendingOp: true,
      );
    });
  }

  /// Usuwa sesje (z ćwiczeniami i seriami) oraz ich ślady w cache historii.
  Future<void> _removeLocalSessions(Set<String> localIds) async {
    if (localIds.isEmpty) return;
    final cacheIds = <String>{...localIds};
    await _localDb.run((db) async {
      await db.transaction((txn) async {
        for (final localId in localIds) {
          final rows = await txn.query(
            ExerciseDatabase.tableTrainingSessions,
            columns: ['server_id'],
            where: 'local_id = ?',
            whereArgs: [localId],
            limit: 1,
          );
          final serverId = rows.isEmpty
              ? null
              : rows.first['server_id'] as String?;
          if (serverId != null) cacheIds.add(serverId);
          await TrainingSessionLocalMapper.deleteSession(txn, localId);
        }
      });
    });
    for (final localId in localIds) {
      await _localDb.clearSyncAttempts(localId);
    }
    await _historyCache.removeSessions(cacheIds);
  }

  // ── Pull ──────────────────────────────────────────────────────────────────

  Future<void> _pullImpl() async {
    if (isStopped) return;
    markPullAttempt();
    try {
      final storedMark = DateTime.tryParse(
        await _localDb.readSyncState(pullHighWaterMarkKey) ?? '',
      )?.toUtc();
      final updatedSince = storedMark?.subtract(pullOverlap);

      DateTime? highWaterMark = storedMark;
      void advance(DateTime? seen) {
        if (seen == null) return;
        final current = highWaterMark;
        if (current == null || seen.isAfter(current)) highWaterMark = seen;
      }

      var changed = false;
      final seenServerIds = <String>{};
      final tombstones = <TrainingSessionTombstone>[];
      String? cursor;
      var completed = false;
      for (var page = 0; page < _maxPullPages; page++) {
        final result = await _remote.history(
          limit: pullPageSize,
          cursor: cursor,
          updatedSince: updatedSince,
        );
        if (isStopped) return;
        for (final item in result.items) {
          final serverId = item.session.serverId;
          if (serverId != null) seenServerIds.add(serverId);
          if (await _storeFromHistory(item)) changed = true;
          advance(item.updatedAt);
        }
        if (page == 0) tombstones.addAll(result.deleted);
        cursor = result.hasMore ? result.nextCursor : null;
        if (cursor == null) {
          completed = true;
          break;
        }
      }
      if (!completed) return;

      for (final tombstone in tombstones) {
        advance(tombstone.deletedAt);
      }
      final removed = await _localIdsForTombstones(tombstones);
      if (updatedSince == null) {
        // Pełna historia: lokalne zsynchronizowane sesje, których serwer już
        // nie ma, zostały usunięte gdzie indziej (zanim był znacznik).
        removed.addAll(await _orphanedSyncedSessions(seenServerIds));
      }
      if (removed.isNotEmpty) {
        await _removeLocalSessions(removed);
        changed = true;
      }

      final mark = highWaterMark;
      if (mark != null && mark != storedMark) {
        await _localDb.writeSyncState(
          pullHighWaterMarkKey,
          mark.toUtc().toIso8601String(),
        );
      }
      if (changed) notifyDataChanged();
    } on ApiException catch (e) {
      registerFailure(e);
    } on StateError {
      /* DB closing */
    }
  }

  /// Zapisuje sesję z historii serwera. Zwraca `true`, gdy zmieniła dane
  /// lokalne.
  ///
  /// * Parowanie: najpierw `server_id`, potem `local_id = clientId` (sesja
  ///   z tego urządzenia, której odpowiedź na POST się zgubiła).
  /// * Wiersz z `pending_op` (niewysłana edycja, usunięcie, odrzucona zmiana)
  ///   nie jest nadpisywany — dostaje co najwyżej brakujące `server_id`.
  /// * Ta sama wersja (`server_updated_at`) jest pomijana.
  Future<bool> _storeFromHistory(PulledTrainingSession item) async {
    final session = item.session;
    final serverId = session.serverId;
    if (serverId == null) return false;
    final serverUpdatedAt = TrainingSessionLocalMapper.encodeDate(
      item.updatedAt,
    );
    return _localDb.run((db) async {
      return db.transaction((txn) async {
        var rows = await txn.query(
          ExerciseDatabase.tableTrainingSessions,
          where: 'server_id = ?',
          whereArgs: [serverId],
          limit: 1,
        );
        if (rows.isEmpty && session.id != serverId) {
          rows = await txn.query(
            ExerciseDatabase.tableTrainingSessions,
            where: 'local_id = ?',
            whereArgs: [session.id],
            limit: 1,
          );
        }
        final row = rows.isEmpty ? null : rows.first;

        if (row != null) {
          final pending = row['pending_op'] as String?;
          if (pending != null) {
            if (row['server_id'] == null) {
              await txn.update(
                ExerciseDatabase.tableTrainingSessions,
                {'server_id': serverId},
                where: 'local_id = ?',
                whereArgs: [row['local_id']],
              );
            }
            return false;
          }
          if (serverUpdatedAt != null &&
              row['server_updated_at'] == serverUpdatedAt &&
              row['server_id'] == serverId) {
            return false;
          }
        }

        final localId = (row?['local_id'] as String?) ?? session.id;
        // Inny wiersz z tym server_id (ślad starszych wersji) złamałby UNIQUE.
        await txn.delete(
          ExerciseDatabase.tableTrainingSessions,
          where: 'server_id = ? AND local_id <> ?',
          whereArgs: [serverId, localId],
        );
        await TrainingSessionLocalMapper.upsert(
          txn,
          session.copyWith(id: localId, serverId: serverId),
          serverId: serverId,
          clearPendingOp: true,
        );
        await txn.update(
          ExerciseDatabase.tableTrainingSessions,
          {'server_updated_at': serverUpdatedAt},
          where: 'local_id = ?',
          whereArgs: [localId],
        );
        return true;
      });
    });
  }

  /// Lokalne wiersze wskazane przez nagrobki: po `clientId`, potem po id.
  ///
  /// Usunięcie na innym urządzeniu wygrywa z niewysłaną lokalną edycją
  /// (tak samo odpowiedziałby serwer: `410`) i z lokalnym usunięciem (cel
  /// osiągnięty). Wyjątek: trwający trening na tym urządzeniu nie znika spod
  /// palców — jeśli naprawdę jest usunięty, jego zapis dostanie `410`.
  Future<Set<String>> _localIdsForTombstones(
    List<TrainingSessionTombstone> tombstones,
  ) async {
    if (tombstones.isEmpty) return <String>{};
    return _localDb.run((db) async {
      final result = <String>{};
      for (final tombstone in tombstones) {
        final matches = <Map<String, Object?>>[];
        final clientId = tombstone.clientId;
        if (clientId != null) {
          matches.addAll(
            await db.query(
              ExerciseDatabase.tableTrainingSessions,
              columns: ['local_id', 'status'],
              where: 'local_id = ?',
              whereArgs: [clientId],
            ),
          );
        }
        matches.addAll(
          await db.query(
            ExerciseDatabase.tableTrainingSessions,
            columns: ['local_id', 'status'],
            where: 'server_id = ?',
            whereArgs: [tombstone.id],
          ),
        );
        for (final row in matches) {
          if (row['status'] == TrainingSessionStatus.active.name) continue;
          result.add(row['local_id'] as String);
        }
      }
      return result;
    });
  }

  Future<Set<String>> _orphanedSyncedSessions(Set<String> serverIds) {
    return _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingSessions,
        columns: ['local_id', 'server_id'],
        where:
            'pending_op IS NULL AND sync_error IS NULL AND server_id IS NOT NULL '
            'AND status <> ?',
        whereArgs: [TrainingSessionStatus.active.name],
      );
      return <String>{
        for (final row in rows)
          if (!serverIds.contains(row['server_id'])) row['local_id'] as String,
      };
    });
  }
}

/// Czy wysyłka zmieniła coś, co widać w historii.
enum _FlushOutcome { none, changedHistory }

class _SendResult {
  const _SendResult(this.session);

  final TrainingSession session;
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

