import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/models/exercise.dart';
import '../exercise_database.dart';
import '../exercise_dto.dart';
import '../exercise_remote_data_source.dart';

/// Background sync: pushes pending local mutations and pulls server state.
///
/// All [flush] / [pull] calls are serialized through an internal queue so
/// concurrent bootstrap + UI triggers cannot interleave DB/network steps.
class ExerciseSyncEngine {
  ExerciseSyncEngine({
    required ExerciseRemoteDataSource remote,
    required ExerciseDatabase localDb,
  })  : _remote = remote,
        _localDb = localDb;

  final ExerciseRemoteDataSource _remote;
  final ExerciseDatabase _localDb;

  static const _uuid = Uuid();

  bool _stopped = false;

  /// Ensures [flush] / [pull] never run concurrently.
  Future<void> _queue = Future<void>.value();

  bool get isStopped => _stopped;

  void stop() => _stopped = true;

  /// Fire-and-forget initial flush + pull after login.
  void scheduleBootstrap() {
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await flush();
      await pull();
    } catch (_) {
      /* offline — next user action retries */
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

  Future<void> pull() => _runExclusive(_pullImpl);

  Future<void> _appendOutbox(
    Database db, {
    required String localId,
    required String op,
    String? lastError,
    required int attempts,
  }) async {
    await db.insert(ExerciseDatabase.tableOutboxLog, {
      'local_id': localId,
      'op': op,
      'attempts': attempts,
      'last_error': lastError,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _failureBackoff(
    String localId,
    String op,
    ApiException e,
  ) async {
    await _localDb.run((db) async {
      final rows = await db.rawQuery(
        '''
        SELECT COALESCE(MAX(attempts), 0) AS m
        FROM ${ExerciseDatabase.tableOutboxLog}
        WHERE local_id = ? AND op = ?
        ''',
        [localId, op],
      );
      final maxPrev = (rows.first['m'] as int?) ?? 0;
      final next = maxPrev + 1;
      await _appendOutbox(
        db,
        localId: localId,
        op: op,
        lastError: e.message,
        attempts: next,
      );
    });
    // Retry on the next sync trigger — no in-loop delay (avoids blocking flush).
  }

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

  Future<Map<String, bool>> _fetchServerFavouritesSnapshot() async {
    final all = await _remote.getAll();
    return {for (final e in all) e.id: e.isFavourite};
  }

  Future<void> _flushImpl() async {
    if (_stopped) return;
    try {
      final pendingMaps = await _localDb.run((db) async {
        return db.query(
          ExerciseDatabase.tableExercises,
          where: '(pending_op IS NOT NULL) OR (is_favourite_dirty = 1)',
        );
      });

      if (pendingMaps.isEmpty) return;

      Map<String, bool>? favSnapshot;
      final needsFavProbe = pendingMaps.any((m) {
        final dirty = ((m['is_favourite_dirty'] as int?) ?? 0) == 1;
        final op = m['pending_op'] as String?;
        return dirty || op == 'create' || op == 'update';
      });
      if (needsFavProbe) {
        try {
          favSnapshot = await _fetchServerFavouritesSnapshot();
        } on ApiException {
          favSnapshot = null;
        }
      }

      final sorted = [...pendingMaps]
        ..sort((a, b) => _pendingRank(a).compareTo(_pendingRank(b)));

      for (final map in sorted) {
        if (_stopped) return;
        final dto = ExerciseDto.fromMap(map);
        await _flushRow(dto, favSnapshot);
      }
    } on StateError {
      /* ExerciseDatabase closing */
    }
  }

  Future<void> _flushRow(
    ExerciseDto dto,
    Map<String, bool>? favSnapshot,
  ) async {
    if (dto.pendingOp == 'delete') {
      await _flushDelete(dto);
      return;
    }
    if (dto.pendingOp == 'create') {
      await _flushCreate(dto, favSnapshot);
      return;
    }
    if (dto.pendingOp == 'update') {
      await _flushUpdate(dto, favSnapshot);
      return;
    }
    if (dto.isFavouriteDirty && dto.serverId != null) {
      await _flushFavouriteOnly(dto, favSnapshot);
    }
  }

  Future<void> _flushDelete(ExerciseDto dto) async {
    final sid = dto.serverId;
    if (sid == null) return;
    try {
      await _remote.delete(sid);
      await _localDb.run((db) async {
        await db.delete(
          ExerciseDatabase.tableExercises,
          where: 'local_id = ?',
          whereArgs: [dto.localId],
        );
      });
    } on ApiException catch (e) {
      await _failureBackoff(dto.localId, 'delete', e);
    }
  }

  Future<void> _flushCreate(
    ExerciseDto dto,
    Map<String, bool>? favSnapshot,
  ) async {
    try {
      final domain = dto.toDomain();
      final created = await _remote.create(
        name: domain.name,
        muscles: domain.muscles,
        category: domain.category,
        description: domain.description,
        clientId: dto.localId,
      );

      await _localDb.run((db) async {
        await db.update(
          ExerciseDatabase.tableExercises,
          {
            'server_id': created.id,
            'pending_op': null,
            'name': created.name,
            'muscles': ExerciseDto.encodeMusclesToJson(created.muscles),
            'category': created.category.name,
            'description': created.description,
            'image_url': created.imageUrl,
            'is_favourite': created.isFavourite ? 1 : 0,
            'is_mine': created.isMine ? 1 : 0,
            if (created.createdAt != null)
              'created_at': created.createdAt!.millisecondsSinceEpoch,
          },
          where: 'local_id = ?',
          whereArgs: [dto.localId],
        );
      });

      final bytes = dto.localImageBytes;
      if (bytes != null &&
          bytes.isNotEmpty &&
          dto.localImageFilename != null &&
          dto.localImageFilename!.isNotEmpty) {
        try {
          final uploaded = await _remote.uploadExerciseImage(
            created.id,
            bytes,
            dto.localImageFilename!,
          );
          await _localDb.run((db) async {
            await db.update(
              ExerciseDatabase.tableExercises,
              {
                'image_url': uploaded.imageUrl,
                'local_image_bytes': null,
                'local_image_filename': null,
              },
              where: 'local_id = ?',
              whereArgs: [dto.localId],
            );
          });
        } on ApiException catch (e) {
          await _failureBackoff(dto.localId, 'image', e);
        }
      }

      final refreshed = await _localDb.run((db) async {
        final rows = await db.query(
          ExerciseDatabase.tableExercises,
          where: 'local_id = ?',
          whereArgs: [dto.localId],
        );
        return rows.isEmpty ? null : ExerciseDto.fromMap(rows.first);
      });
      if (refreshed != null &&
          refreshed.isFavouriteDirty &&
          refreshed.serverId != null) {
        await _flushFavouriteOnly(refreshed, favSnapshot);
      }
    } on ApiException catch (e) {
      await _failureBackoff(dto.localId, 'create', e);
    }
  }

  Future<void> _flushUpdate(
    ExerciseDto dto,
    Map<String, bool>? favSnapshot,
  ) async {
    final sid = dto.serverId;
    if (sid == null) return;
    try {
      final domain = dto.toDomain();
      final updated = await _remote.update(
        id: sid,
        name: domain.name,
        muscles: domain.muscles,
        category: domain.category,
        description: domain.description,
      );
      await _localDb.run((db) async {
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

      final refreshed = await _localDb.run((db) async {
        final rows = await db.query(
          ExerciseDatabase.tableExercises,
          where: 'local_id = ?',
          whereArgs: [dto.localId],
        );
        return rows.isEmpty ? null : ExerciseDto.fromMap(rows.first);
      });
      if (refreshed != null &&
          refreshed.isFavouriteDirty &&
          refreshed.serverId != null) {
        await _flushFavouriteOnly(refreshed, favSnapshot);
      }
    } on ApiException catch (e) {
      await _failureBackoff(dto.localId, 'update', e);
    }
  }

  Future<void> _flushFavouriteOnly(
    ExerciseDto dto,
    Map<String, bool>? favSnapshot,
  ) async {
    final sid = dto.serverId;
    if (sid == null) return;

    try {
      final Map<String, bool> snapshot;
      if (favSnapshot != null) {
        snapshot = favSnapshot;
      } else {
        snapshot = await _fetchServerFavouritesSnapshot();
      }

      var serverFav = snapshot[sid];
      if (serverFav == null) {
        final full = await _remote.getAll();
        for (final e in full) {
          if (e.id == sid) {
            serverFav = e.isFavourite;
            break;
          }
        }
      }
      if (serverFav == null) return;

      final target = dto.isFavourite;
      if (serverFav == target) {
        await _localDb.run((db) async {
          await db.update(
            ExerciseDatabase.tableExercises,
            {'is_favourite_dirty': 0},
            where: 'local_id = ?',
            whereArgs: [dto.localId],
          );
        });
        return;
      }

      var afterServer = await _remote.toggleFavourite(sid);
      if (afterServer != target) {
        afterServer = await _remote.toggleFavourite(sid);
      }

      await _localDb.run((db) async {
        await db.update(
          ExerciseDatabase.tableExercises,
          {
            'is_favourite': afterServer ? 1 : 0,
            'is_favourite_dirty': 0,
          },
          where: 'local_id = ?',
          whereArgs: [dto.localId],
        );
      });
    } on ApiException catch (e) {
      await _failureBackoff(dto.localId, 'favourite', e);
    }
  }

  Future<void> _pullImpl() async {
    if (_stopped) return;
    try {
      final server = await _remote.getAll();
      if (_stopped) return;
      await _localDb.run((db) async {
        await _reconcilePull(db, server);
      });
    } on ApiException {
      /* offline */
    } on StateError {
      /* DB closing */
    }
  }

  Future<void> _reconcilePull(Database db, List<Exercise> server) async {
    final serverIds = server.map((e) => e.id).toSet();

    for (final ex in server) {
      final rows = await db.query(
        ExerciseDatabase.tableExercises,
        where: 'server_id = ? OR local_id = ?',
        whereArgs: [ex.id, ex.id],
      );

      if (rows.isEmpty) {
        final dto = ExerciseDto.fromPulledServer(ex, _uuid.v4());
        await db.insert(
          ExerciseDatabase.tableExercises,
          dto.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        final row = rows.first;
        final pending = row['pending_op'] as String?;
        if (pending != null) continue;

        final favDirty = ((row['is_favourite_dirty'] as int?) ?? 0) == 1;

        final localId = row['local_id'] as String;
        await db.update(
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
    }

    final locals = await db.query(
      ExerciseDatabase.tableExercises,
      columns: ['local_id', 'server_id', 'pending_op', 'is_favourite_dirty'],
    );

    for (final m in locals) {
      final pending = m['pending_op'] as String?;
      if (pending != null) continue;
      final favDirty = ((m['is_favourite_dirty'] as int?) ?? 0) == 1;
      if (favDirty) continue;

      final sid = m['server_id'] as String?;
      if (sid == null) continue;
      if (!serverIds.contains(sid)) {
        await db.delete(
          ExerciseDatabase.tableExercises,
          where: 'local_id = ?',
          whereArgs: [m['local_id']],
        );
      }
    }
  }
}
