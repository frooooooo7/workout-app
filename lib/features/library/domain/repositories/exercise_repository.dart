import '../models/exercise.dart';

abstract interface class ExerciseRepository {
  /// Returns all exercises, applying optional filters.
  Future<List<Exercise>> getAll({
    MuscleGroup? muscleGroup,
    LibraryFilter? filter,
    String? query,
  });

  /// Toggles favourite state for the given [id].
  Future<void> setFavourite(String id, {required bool isFavourite});

  /// Inserts or updates a custom (user-created) exercise.
  Future<void> upsert(Exercise exercise);

  /// Deletes a user-created exercise by [id].
  Future<void> delete(String id);

  /// Seeds built-in exercises if the database is empty.
  Future<void> seedIfEmpty(List<Exercise> builtIn);
}
