import 'package:sqflite/sqflite.dart';

import '../../../core/network/api_client.dart';
import '../domain/models/exercise.dart';
import '../domain/repositories/exercise_repository.dart';
import 'exercise_database.dart';
import 'exercise_dto.dart';
import 'exercise_filter_utils.dart';
import 'exercise_remote_data_source.dart';

/// [ExerciseRepository] that treats the backend as the source of truth and
/// uses local SQLite as a per-user offline cache.
///
/// **Read strategy (getAll):**
///   • Unfiltered fetch (all, no query) → full cache replacement: DELETE all
///     + INSERT fresh data so stale/deleted records don't persist.
///   • Filtered fetch → upsert without purging (partial sync).
///   • Any [ApiException] → fall back to local SQLite with in-memory filters.
///
/// **Write strategy (setFavourite):**
///   1. Optimistic SQLite update (instant UI response).
///   2. POST to API; use the **server's returned state** to reconcile cache.
///   3. On [ApiException] → local change kept until next successful getAll().
///
/// **Write strategy (create / update / delete):**
///   Requires connectivity — throws on API failure so the UI can show an error.
class CachedExerciseRepository implements ExerciseRepository {
  const CachedExerciseRepository({
    required ExerciseRemoteDataSource remote,
    required ExerciseDatabase localDb,
  })  : _remote = remote,
        _localDb = localDb;

  final ExerciseRemoteDataSource _remote;
  final ExerciseDatabase _localDb;

  // ── Cache helpers ─────────────────────────────────────────────────────────

  /// Full replacement: wipes the local table and inserts [exercises].
  /// Used on unfiltered fetches so deleted server-side records don't linger.
  Future<void> _replaceAll(List<Exercise> exercises) async {
    final db = await _localDb.db;
    await db.transaction((txn) async {
      await txn.delete(ExerciseDatabase.tableExercises);
      final batch = txn.batch();
      for (final e in exercises) {
        batch.insert(
          ExerciseDatabase.tableExercises,
          ExerciseDto.fromDomain(e).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Partial upsert: inserts / updates without touching other records.
  /// Used on filtered fetches where we can't know what was omitted.
  Future<void> _upsertAll(List<Exercise> exercises) async {
    final db = await _localDb.db;
    final batch = db.batch();
    for (final e in exercises) {
      batch.insert(
        ExerciseDatabase.tableExercises,
        ExerciseDto.fromDomain(e).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Exercise>> _localGetAll({
    MuscleGroup? muscleGroup,
    LibraryFilter? filter,
    String? query,
  }) async {
    final db = await _localDb.db;
    final maps = await db.query(ExerciseDatabase.tableExercises);
    final all = maps.map((m) => ExerciseDto.fromMap(m).toDomain()).toList();
    return ExerciseFilterUtils.apply(all,
        muscleGroup: muscleGroup, filter: filter, query: query);
  }

  bool _isUnfiltered({
    MuscleGroup? muscleGroup,
    LibraryFilter? filter,
    String? query,
  }) =>
      (muscleGroup == null || muscleGroup == MuscleGroup.all) &&
      (filter == null || filter == LibraryFilter.all) &&
      (query == null || query.isEmpty);

  // ── ExerciseRepository ────────────────────────────────────────────────────

  @override
  Future<List<Exercise>> getAll({
    MuscleGroup? muscleGroup,
    LibraryFilter? filter,
    String? query,
  }) async {
    try {
      final exercises = await _remote.getAll(
        muscleGroup: muscleGroup,
        filter: filter,
        query: query,
      );

      // Full sync on unfiltered fetch: purge stale records.
      // Partial upsert on filtered fetch: don't touch records outside the filter.
      if (_isUnfiltered(muscleGroup: muscleGroup, filter: filter, query: query)) {
        _replaceAll(exercises).ignore();
      } else {
        _upsertAll(exercises).ignore();
      }

      return exercises;
    } on ApiException {
      return _localGetAll(
          muscleGroup: muscleGroup, filter: filter, query: query);
    }
  }

  @override
  Future<void> setFavourite(String id, {required bool isFavourite}) async {
    // Optimistic local update — gives instant UI feedback.
    final db = await _localDb.db;
    await db.update(
      ExerciseDatabase.tableExercises,
      {'is_favourite': isFavourite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );

    try {
      // Use the server's authoritative returned state to reconcile the cache.
      final serverState = await _remote.toggleFavourite(id);
      if (serverState != isFavourite) {
        await db.update(
          ExerciseDatabase.tableExercises,
          {'is_favourite': serverState ? 1 : 0},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    } on ApiException {
      // Offline: optimistic local change is kept.
      // The true server state will be restored on the next successful getAll().
    }
  }

  @override
  Future<Exercise> create({
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
  }) async {
    final created = await _remote.create(
        name: name, muscles: muscles, category: category);
    await _upsertAll([created]);
    return created;
  }

  @override
  Future<Exercise> update({
    required String id,
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
  }) async {
    final updated = await _remote.update(
        id: id, name: name, muscles: muscles, category: category);
    await _upsertAll([updated]);
    return updated;
  }

  @override
  Future<void> delete(String id) async {
    await _remote.delete(id);
    final db = await _localDb.db;
    await db.delete(ExerciseDatabase.tableExercises,
        where: 'id = ?', whereArgs: [id]);
  }
}
