import 'package:sqflite/sqflite.dart';

import '../domain/models/exercise.dart';
import '../domain/repositories/exercise_repository.dart';
import 'exercise_database.dart';
import 'exercise_dto.dart';

class SqfliteExerciseRepository implements ExerciseRepository {
  const SqfliteExerciseRepository(this._dbInstance);

  final ExerciseDatabase _dbInstance;

  Future<Database> get _db => _dbInstance.db;

  @override
  Future<List<Exercise>> getAll({
    MuscleGroup? muscleGroup,
    LibraryFilter? filter,
    String? query,
  }) async {
    final db = await _db;
    final maps = await db.query(ExerciseDatabase.tableExercises);

    var exercises = maps.map((m) => ExerciseDto.fromMap(m).toDomain()).toList();

    // Filter: tab chip
    if (filter == LibraryFilter.mine) {
      exercises = exercises.where((e) => e.isMine).toList();
    } else if (filter == LibraryFilter.favourite) {
      exercises = exercises.where((e) => e.isFavourite).toList();
    } else if (filter == LibraryFilter.recent) {
      exercises = exercises.where((e) => e.isMine || e.isFavourite).toList();
    }

    // Filter: muscle group
    if (muscleGroup != null && muscleGroup != MuscleGroup.all) {
      exercises =
          exercises.where((e) => e.muscles.contains(muscleGroup)).toList();
    }

    // Filter: search query
    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      exercises = exercises.where((e) {
        final matchName = e.name.toLowerCase().contains(q);
        final matchMuscle =
            e.muscles.any((m) => m.label.toLowerCase().contains(q));
        return matchName || matchMuscle;
      }).toList();
    }

    return exercises;
  }

  @override
  Future<void> setFavourite(String id, {required bool isFavourite}) async {
    final db = await _db;
    await db.update(
      ExerciseDatabase.tableExercises,
      {'is_favourite': isFavourite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> upsert(Exercise exercise) async {
    final db = await _db;
    final dto = ExerciseDto.fromDomain(exercise);
    await db.insert(
      ExerciseDatabase.tableExercises,
      dto.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete(
      ExerciseDatabase.tableExercises,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> seedIfEmpty(List<Exercise> builtIn) async {
    final db = await _db;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
          'SELECT COUNT(*) FROM ${ExerciseDatabase.tableExercises}'),
    );
    if (count != null && count > 0) return;

    final batch = db.batch();
    for (final e in builtIn) {
      batch.insert(
        ExerciseDatabase.tableExercises,
        ExerciseDto.fromDomain(e).toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }
}
