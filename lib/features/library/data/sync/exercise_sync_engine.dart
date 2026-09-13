import 'dart:async';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/sync/sync_engine_base.dart';
import '../../../../core/sync/sync_failure.dart';
import '../../domain/models/exercise.dart';
import '../exercise_database.dart';
import '../exercise_dto.dart';
import '../exercise_remote_data_source.dart';

/// Background sync: pushes pending local mutations and pulls server state.
///
/// All [flush] / [pull] calls are serialized through [SyncEngineBase] so
/// concurrent bootstrap + UI triggers cannot interleave DB/network steps.
class ExerciseSyncEngine extends SyncEngineBase {
  ExerciseSyncEngine({
    required ExerciseRemoteDataSource remote,
    required ExerciseDatabase localDb,
    super.onDataChanged,
  }) : _remote = remote,
       _localDb = localDb;

  final ExerciseRemoteDataSource _remote;
  final ExerciseDatabase _localDb;

  static const _uuid = Uuid();

  /// Fire-and-forget initial flush + pull after login.
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
      await pull();
    } catch (_) {
      /* offline — next trigger retries */
    }
  }

  Future<void> flush() => runCoalesced('flush', _flushImpl);

  Future<void> pull() => runCoalesced('pull', _pullImpl);

  /// Pobiera stan serwera tylko wtedy, gdy ostatnia próba była dawniej niż
  /// [maxAge] — zmiana filtra czy wyszukiwanie nie ciągną całej listy z sieci.
  Future<void> pullIfDue({
    Duration maxAge = SyncEngineBase.defaultPullMaxAge,
  }) {
    return runCoalesced('pull-if-due', () async {
      if (isPullDue(maxAge)) await _pullImpl();
    });
  }

  // ── Failures ──────────────────────────────────────────────────────────────

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
        table: ExerciseDatabase.tableExercises,
        localId: localId,
        reason: error.message,
      );
    }
  }

  /// Wywołuje API; błąd zapisuje (i ewentualnie oznacza wiersz jako
  /// odrzucony) i zwraca `null`.
  Future<T?> _callRemote<T extends Object>(
    String localId,
    String op,
    Future<T> Function() call,
  ) async {
    try {
      return await call();
    } on ApiException catch (e) {
      await _handleFailure(localId, op, e);
      return null;
    }
  }

  // ── Flush ─────────────────────────────────────────────────────────────────

  int _pendingRank(Map<String, dynamic> m) {
    final op = m['pending_op'] as String?;
    final dirty = ((m['is_favourite_dirty'] as int?) ?? 0) == 1;
    if (op == 'create') return 0;
    if (op == 'update') return 1;
    if (dirty && (op == null || op.isEmpty)) return 2;
    if (op == 'delete') return 3;
    if (dirty) return 2;
    return 4;
  }

  Future<List<Map<String, dynamic>>?> _pendingRows() async {
    try {
      return await _localDb.run(
        (db) => db.query(
          ExerciseDatabase.tableExercises,
          where:
              '((pending_op IS NOT NULL) OR (is_favourite_dirty = 1)) '
              'AND sync_error IS NULL',
        ),
      );
    } on StateError {
      return null; /* ExerciseDatabase closing */
    }
  }

  Future<void> _flushImpl() async {
    if (isStopped) return;
    final pendingMaps = await _pendingRows();
    if (pendingMaps == null || pendingMaps.isEmpty) return;

    final sorted = [...pendingMaps]
      ..sort((a, b) => _pendingRank(a).compareTo(_pendingRank(b)));

    final networkMark = networkFailureMark;
    var changed = false;
    for (final map in sorted) {
      if (isStopped) return;
      try {
        if (await _flushRow(ExerciseDto.fromMap(map))) {
          changed = true;
        }
      } catch (error, stackTrace) {
        if (isStopped) return;
        // Jeden uszkodzony wiersz nie może zablokować wysyłki pozostałych.
        logUnexpected(
          'Exercise ${map['local_id']} sync failed',
          error,
          stackTrace,
        );
      }
      if (networkFailedSince(networkMark)) break;
    }
    if (changed) notifyDataChanged();
  }

  /// Zwraca `true`, gdy coś zostało wysłane.
  Future<bool> _flushRow(ExerciseDto dto) async {
    if (dto.pendingOp == 'delete') return _flushDelete(dto);
    if (dto.pendingOp == 'create') return _flushCreate(dto);
    if (dto.pendingOp == 'update') return _flushUpdate(dto);
    if (dto.isFavouriteDirty && dto.serverId != null) {
      return _flushFavouriteOnly(dto);
    }
    return false;
  }

  Future<bool> _flushDelete(ExerciseDto dto) async {
    final sid = dto.serverId;
    if (sid != null) {
      try {
        await _remote.delete(sid);
      } on ApiException catch (e) {
        // 404 — ćwiczenia już nie ma na serwerze, cel usunięcia osiągnięty.
        if (e.statusCode != 404) {
          await _handleFailure(dto.localId, 'delete', e);
          return false;
        }
      }
    }
    await _localDb.run(
      (db) => db.delete(
        ExerciseDatabase.tableExercises,
        where: 'local_id = ?',
        whereArgs: [dto.localId],
      ),
    );
    await _localDb.clearSyncAttempts(dto.localId);
    return true;
  }

  Future<bool> _flushCreate(ExerciseDto dto) async {
    final domain = dto.toDomain();
    final created = await _callRemote(
      dto.localId,
      'create',
      () => _remote.create(
        name: domain.name,
        muscles: domain.muscles,
        category: domain.category,
        description: domain.description,
        clientId: dto.localId,
      ),
    );
    if (created == null) return false;

    final rowStillExists = await _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableExercises,
        where: 'local_id = ?',
        whereArgs: [dto.localId],
        limit: 1,
      );
      await _adoptServerId(db, serverId: created.id, localId: dto.localId);

      if (rows.isEmpty) {
        // Usunięte, zanim serwer odpowiedział — nagrobek usunie je też
        // z serwera przy następnej wysyłce.
        await db.insert(ExerciseDatabase.tableExercises, {
          ...ExerciseDto.fromPulledServer(created, dto.localId).toMap(),
          'pending_op': 'delete',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        return false;
      }

      final current = ExerciseDto.fromMap(rows.first);
      final values = <String, Object?>{'server_id': created.id};
      if (_sameContent(current, dto)) {
        values.addAll({
          'pending_op': null,
          'name': created.name,
          'muscles': ExerciseDto.encodeMusclesToJson(created.muscles),
          'category': created.category.name,
          'description': created.description,
          'image_url': created.imageUrl,
          'is_mine': created.isMine ? 1 : 0,
          // Ulubione zmienione w trakcie wysyłki wyśle _flushFavouriteOnly.
          if (!current.isFavouriteDirty)
            'is_favourite': created.isFavourite ? 1 : 0,
          if (created.createdAt != null)
            'created_at': created.createdAt!.millisecondsSinceEpoch,
        });
      } else {
        // Edytowane w trakcie wysyłki — nowsza wersja pójdzie jako update.
        values['pending_op'] = 'update';
      }
      await db.update(
        ExerciseDatabase.tableExercises,
        values,
        where: 'local_id = ?',
        whereArgs: [dto.localId],
      );
      return true;
    });
    if (!rowStillExists) return false;

    await _finishServerWrite(dto.localId, created.id);
    return true;
  }

  Future<bool> _flushUpdate(ExerciseDto dto) async {
    final sid = dto.serverId;
    if (sid == null) return false;
    final domain = dto.toDomain();
    final updated = await _callRemote(
      dto.localId,
      'update',
      () => _remote.update(
        id: sid,
        name: domain.name,
        muscles: domain.muscles,
        category: domain.category,
        description: domain.description,
      ),
    );
    if (updated == null) return false;

    await _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableExercises,
        where: 'local_id = ?',
        whereArgs: [dto.localId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final current = ExerciseDto.fromMap(rows.first);
      // Zmienione (albo usunięte) w trakcie wysyłki — zostaw na kolejny cykl.
      if (current.pendingOp != 'update' || !_sameContent(current, dto)) return;
      await db.update(
        ExerciseDatabase.tableExercises,
        {
          'pending_op': null,
          'name': updated.name,
          'muscles': ExerciseDto.encodeMusclesToJson(updated.muscles),
          'category': updated.category.name,
          'description': updated.description,
          'image_url': updated.imageUrl,
          if (updated.createdAt != null)
            'created_at': updated.createdAt!.millisecondsSinceEpoch,
        },
        where: 'local_id = ?',
        whereArgs: [dto.localId],
      );
    });

    await _finishServerWrite(dto.localId, sid);
    return true;
  }

  /// Wspólny ogon create/update: zdjęcie dodane offline i ulubione.
  Future<void> _finishServerWrite(String localId, String serverId) async {
    final imageUploaded = await _uploadPendingImage(localId, serverId);
    if (!imageUploaded) {
      // Zdjęcie nie doszło — zostaw wiersz w kolejce, żeby ponowić wysyłkę.
      await _localDb.run(
        (db) => db.update(
          ExerciseDatabase.tableExercises,
          {'pending_op': 'update'},
          where: 'local_id = ? AND pending_op IS NULL',
          whereArgs: [localId],
        ),
      );
    }

    final refreshed = await _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableExercises,
        where: 'local_id = ?',
        whereArgs: [localId],
        limit: 1,
      );
      return rows.isEmpty ? null : ExerciseDto.fromMap(rows.first);
    });
    if (refreshed != null &&
        refreshed.isFavouriteDirty &&
        refreshed.serverId != null) {
      await _flushFavouriteOnly(refreshed);
    }
    if (imageUploaded) await _localDb.clearSyncAttempts(localId);
  }

  /// Wysyła zdjęcie zapisane offline. `true`, gdy nie było czego wysyłać
  /// albo wysyłka się udała.
  Future<bool> _uploadPendingImage(String localId, String serverId) async {
    final row = await _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableExercises,
        columns: ['local_image_bytes', 'local_image_filename'],
        where: 'local_id = ?',
        whereArgs: [localId],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first;
    });
    final bytes = row?['local_image_bytes'] as Uint8List?;
    final filename = row?['local_image_filename'] as String?;
    if (bytes == null || bytes.isEmpty || filename == null || filename.isEmpty) {
      return true;
    }

    final uploaded = await _callRemote(
      localId,
      'image',
      () => _remote.uploadExerciseImage(serverId, bytes, filename),
    );
    if (uploaded == null) return false;

    await _localDb.run(
      (db) => db.update(
        ExerciseDatabase.tableExercises,
        {
          'image_url': uploaded.imageUrl,
          'local_image_bytes': null,
          'local_image_filename': null,
        },
        where: 'local_id = ?',
        whereArgs: [localId],
      ),
    );
    return true;
  }

  /// Bez pobierania całej biblioteki dla porównania — API nie ma
  /// GET /exercises/:id, a odpowiedź toggle zwraca stan po zmianie.
  Future<bool> _flushFavouriteOnly(ExerciseDto dto) async {
    final sid = dto.serverId;
    if (sid == null) return false;

    Future<void> clearDirty() => _localDb.run(
      (db) => db.update(
        ExerciseDatabase.tableExercises,
        {'is_favourite_dirty': 0},
        where: 'local_id = ?',
        whereArgs: [dto.localId],
      ),
    );

    try {
      final target = dto.isFavourite;
      var afterServer = await _remote.toggleFavourite(sid);
      if (afterServer != target) {
        afterServer = await _remote.toggleFavourite(sid);
      }

      await _localDb.run(
        (db) => db.update(
          ExerciseDatabase.tableExercises,
          {'is_favourite': afterServer ? 1 : 0, 'is_favourite_dirty': 0},
          // Kliknięte ponownie w trakcie wysyłki — zostaw flagę na kolejny cykl.
          where: 'local_id = ? AND is_favourite = ?',
          whereArgs: [dto.localId, target ? 1 : 0],
        ),
      );
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        await clearDirty();
        return true;
      }
      await _handleFailure(dto.localId, 'favourite', e);
      return false;
    }
  }

  bool _sameContent(ExerciseDto a, ExerciseDto b) =>
      a.name == b.name &&
      a.muscles == b.muscles &&
      a.category == b.category &&
      a.description == b.description;

  /// Przed przypisaniem [serverId] do wiersza [localId] usuwa duplikat, który
  /// mogło wstawić wcześniejsze pobranie (np. po zgubionej odpowiedzi na
  /// create), i przepina na [localId] odwołania z planów i sesji.
  Future<void> _adoptServerId(
    DatabaseExecutor db, {
    required String serverId,
    required String localId,
  }) async {
    final duplicates = await db.query(
      ExerciseDatabase.tableExercises,
      columns: ['local_id'],
      where: 'server_id = ? AND local_id <> ?',
      whereArgs: [serverId, localId],
    );
    for (final duplicate in duplicates) {
      final duplicateId = duplicate['local_id'] as String;
      await db.update(
        ExerciseDatabase.tableTrainingPlanExercises,
        {'exercise_local_id': localId},
        where: 'exercise_local_id = ?',
        whereArgs: [duplicateId],
      );
      await db.update(
        ExerciseDatabase.tableTrainingSessionExercises,
        {'exercise_local_id': localId},
        where: 'exercise_local_id = ?',
        whereArgs: [duplicateId],
      );
      await db.delete(
        ExerciseDatabase.tableExercises,
        where: 'local_id = ?',
        whereArgs: [duplicateId],
      );
    }
  }

  // ── Pull ──────────────────────────────────────────────────────────────────

  Future<void> _pullImpl() async {
    if (isStopped) return;
    markPullAttempt();
    try {
      final server = await _remote.getAll();
      if (isStopped) return;
      await _localDb.run((db) => _reconcilePull(db, server));
      notifyDataChanged();
    } on ApiException catch (e) {
      registerFailure(e);
    } on StateError {
      /* DB closing */
    }
  }

  static const _inChunkSize = 900;

  Future<void> _reconcilePull(Database db, List<Exercise> server) async {
    await db.transaction((txn) async {
      final locals = await txn.query(
        ExerciseDatabase.tableExercises,
        columns: ['local_id', 'server_id', 'pending_op', 'is_favourite_dirty'],
      );
      final byLocalId = <String, Map<String, dynamic>>{
        for (final row in locals) row['local_id'] as String: row,
      };
      final byServerId = <String, Map<String, dynamic>>{
        for (final row in locals)
          if (row['server_id'] != null) row['server_id'] as String: row,
      };
      final serverIds = server.map((e) => e.id).toSet();

      final batch = txn.batch();
      for (final ex in server) {
        var row = byServerId[ex.id] ?? byLocalId[ex.id];
        final clientId = ex.clientId;
        if (row == null && clientId != null) {
          // Utworzone offline na tym urządzeniu — serwer odsyła nasz local_id.
          row = byLocalId[clientId];
        }

        if (row == null) {
          final dto = ExerciseDto.fromPulledServer(ex, _uuid.v4());
          batch.insert(
            ExerciseDatabase.tableExercises,
            dto.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          continue;
        }

        final localId = row['local_id'] as String;
        final linkedToServer = row['server_id'] == ex.id;

        if (row['pending_op'] != null) {
          // Lokalne zmiany mają pierwszeństwo — zapamiętaj tylko, któremu
          // rekordowi na serwerze odpowiada wiersz.
          if (!linkedToServer) {
            await _adoptServerId(txn, serverId: ex.id, localId: localId);
            batch.update(
              ExerciseDatabase.tableExercises,
              {'server_id': ex.id},
              where: 'local_id = ?',
              whereArgs: [localId],
            );
          }
          continue;
        }

        final favDirty = ((row['is_favourite_dirty'] as int?) ?? 0) == 1;
        if (!linkedToServer) {
          await _adoptServerId(txn, serverId: ex.id, localId: localId);
        }
        batch.update(
          ExerciseDatabase.tableExercises,
          {
            'server_id': ex.id,
            'name': ex.name,
            'muscles': ExerciseDto.encodeMusclesToJson(ex.muscles),
            'category': ex.category.name,
            'description': ex.description,
            'image_url': ex.imageUrl,
            if (!favDirty) 'is_favourite': ex.isFavourite ? 1 : 0,
            'is_mine': ex.isMine ? 1 : 0,
            if (ex.createdAt != null)
              'created_at': ex.createdAt!.millisecondsSinceEpoch,
          },
          where: 'local_id = ?',
          whereArgs: [localId],
        );
      }
      await batch.commit(noResult: true);

      final orphanIds = <String>[];
      for (final row in locals) {
        if (row['pending_op'] != null) continue;
        if (((row['is_favourite_dirty'] as int?) ?? 0) == 1) continue;
        final sid = row['server_id'] as String?;
        if (sid == null || serverIds.contains(sid)) continue;
        orphanIds.add(row['local_id'] as String);
      }
      for (var i = 0; i < orphanIds.length; i += _inChunkSize) {
        final end = i + _inChunkSize > orphanIds.length
            ? orphanIds.length
            : i + _inChunkSize;
        final chunk = orphanIds.sublist(i, end);
        final placeholders = List.filled(chunk.length, '?').join(', ');
        await txn.delete(
          ExerciseDatabase.tableExercises,
          where: 'local_id IN ($placeholders)',
          whereArgs: chunk,
        );
      }
    });
  }
}
