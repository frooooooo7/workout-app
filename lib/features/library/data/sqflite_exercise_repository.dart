import 'package:sqflite/sqflite.dart';

import '../domain/models/exercise.dart';
import '../domain/repositories/exercise_repository.dart';
import 'exercise_database.dart';
import 'exercise_dto.dart';
import 'exercise_filter_utils.dart';

/// Local-only [ExerciseRepository] backed by SQLite.
/// Used in tests or as a standalone fallback where no API is available.
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
    final all = maps.map((m) => ExerciseDto.fromMap(m).toDomain()).toList();
    return ExerciseFilterUtils.apply(all,
        muscleGroup: muscleGroup, filter: filter, query: query);
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
  Future<Exercise> create({
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
  }) async {
    final exercise = Exercise(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      muscles: muscles,
      category: category,
      isMine: true,
      createdAt: DateTime.now().toUtc(),
    );
    final db = await _db;
    await db.insert(
      ExerciseDatabase.tableExercises,
      ExerciseDto.fromDomain(exercise).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return exercise;
  }

  @override
  Future<Exercise> update({
    required String id,
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
  }) async {
    final db = await _db;
    await db.update(
      ExerciseDatabase.tableExercises,
      {
        'name': name,
        'muscles': ExerciseDto.encodeMusclesToJson(muscles),
        'category': category.name,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    final maps = await db.query(
      ExerciseDatabase.tableExercises,
      where: 'id = ?',
      whereArgs: [id],
    );
    return ExerciseDto.fromMap(maps.first).toDomain();
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
}
