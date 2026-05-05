import 'dart:async';
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/errors/exercise_not_found_exception.dart';
import '../domain/models/exercise.dart';
import '../domain/repositories/exercise_repository.dart';
import 'exercise_database.dart';
import 'exercise_dto.dart';
import 'exercise_filter_utils.dart';
import 'sync/exercise_sync_engine.dart';

/// Offline-first library: writes go to SQLite immediately; [ExerciseSyncEngine]
/// pushes/pulls in the background.
class OfflineFirstExerciseRepository implements ExerciseRepository {
  OfflineFirstExerciseRepository({
    required ExerciseDatabase localDb,
    required ExerciseSyncEngine syncEngine,
  })  : _localDb = localDb,
        _sync = syncEngine;

  final ExerciseDatabase _localDb;
  final ExerciseSyncEngine _sync;

  static const _uuid = Uuid();

  Future<Map<String, dynamic>?> _findRow(Database db, String id) async {
    final byLocal = await db.query(
      ExerciseDatabase.tableExercises,
      where: 'local_id = ?',
      whereArgs: [id],
    );
    if (byLocal.isNotEmpty) return byLocal.first;
    final byServer = await db.query(
      ExerciseDatabase.tableExercises,
      where: 'server_id = ?',
      whereArgs: [id],
    );
    if (byServer.isNotEmpty) return byServer.first;
    return null;
  }

  Future<List<Exercise>> _localGetAll({
    MuscleGroup? muscleGroup,
    LibraryFilter? filter,
    String? query,
  }) async {
    return _localDb.run((db) async {
      final maps = await db.query(
        ExerciseDatabase.tableExercises,
        where: '(pending_op IS NULL OR pending_op <> ?)',
        whereArgs: ['delete'],
      );
      final all = maps.map((m) => ExerciseDto.fromMap(m).toDomain()).toList();
      return ExerciseFilterUtils.apply(
        all,
        muscleGroup: muscleGroup,
        filter: filter,
        query: query,
      );
    });
  }

  void _scheduleSync() {
    if (_sync.isStopped) return;
    unawaited(_sync.flush());
    unawaited(_sync.pull());
  }

  @override
  Future<List<Exercise>> getAll({
    MuscleGroup? muscleGroup,
    LibraryFilter? filter,
    String? query,
  }) async {
    final local = await _localGetAll(
      muscleGroup: muscleGroup,
      filter: filter,
      query: query,
    );
    _scheduleSync();
    return local;
  }

  @override
  Future<void> setFavourite(String id, {required bool isFavourite}) async {
    await _localDb.run((db) async {
      final row = await _findRow(db, id);
      if (row == null) return;
      final localId = row['local_id'] as String;
      await db.update(
        ExerciseDatabase.tableExercises,
        {
          'is_favourite': isFavourite ? 1 : 0,
          'is_favourite_dirty': 1,
        },
        where: 'local_id = ?',
        whereArgs: [localId],
      );
    });

    _scheduleSync();
  }

  @override
  Future<Exercise> create({
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
    Uint8List? imageBytes,
    String? imageFilename,
  }) async {
    final localId = _uuid.v4();
    final createdAt = DateTime.now().toUtc();
    final exercise = Exercise(
      id: localId,
      name: name,
      muscles: muscles,
      category: category,
      description: description,
      imageUrl: null,
      isFavourite: false,
      isMine: true,
      createdAt: createdAt,
      isPendingSync: true,
    );

    final dto = ExerciseDto.fromDomain(
      exercise,
      pendingOp: 'create',
      localImageBytes:
          (imageBytes != null && imageBytes.isNotEmpty) ? imageBytes : null,
      localImageFilename: imageFilename,
    );

    await _localDb.run((db) async {
      await db.insert(
        ExerciseDatabase.tableExercises,
        dto.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    _scheduleSync();
    return exercise;
  }

  @override
  Future<Exercise> update({
    required String id,
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
  }) async {
    await _localDb.run((db) async {
      final row = await _findRow(db, id);
      if (row == null) {
        throw ExerciseNotFoundException(id);
      }

      final localId = row['local_id'] as String;
      final pending = row['pending_op'] as String?;
      final nextPending = pending == 'create' ? 'create' : 'update';

      await db.update(
        ExerciseDatabase.tableExercises,
        {
          'name': name,
          'muscles': ExerciseDto.encodeMusclesToJson(muscles),
          'category': category.name,
          'description': description,
          'pending_op': nextPending,
        },
        where: 'local_id = ?',
        whereArgs: [localId],
      );
    });

    _scheduleSync();

    final rowAfter = await _localDb.run((db) => _findRow(db, id));
    if (rowAfter == null) {
      throw ExerciseNotFoundException(id);
    }
    return ExerciseDto.fromMap(rowAfter).toDomain();
  }

  @override
  Future<void> delete(String id) async {
    await _localDb.run((db) async {
      final row = await _findRow(db, id);
      if (row == null) return;
      final localId = row['local_id'] as String;
      final pending = row['pending_op'] as String?;

      if (pending == 'create') {
        await db.delete(
          ExerciseDatabase.tableExercises,
          where: 'local_id = ?',
          whereArgs: [localId],
        );
        await db.insert(ExerciseDatabase.tableOutboxLog, {
          'local_id': localId,
          'op': 'skipped_pending_create',
          'attempts': 0,
          'last_error': null,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
        return;
      }

      await db.update(
        ExerciseDatabase.tableExercises,
        {'pending_op': 'delete'},
        where: 'local_id = ?',
        whereArgs: [localId],
      );
    });

    _scheduleSync();
  }
}
