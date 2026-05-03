import '../models/exercise.dart';

abstract interface class ExerciseRepository {
  /// Returns exercises applying optional filters.
  /// Implementations should attempt a network fetch and fall back to local
  /// cache when the backend is unreachable.
  Future<List<Exercise>> getAll({
    MuscleGroup? muscleGroup,
    LibraryFilter? filter,
    String? query,
  });

  /// Toggles favourite state for the given [id].
  /// Implementations should optimistically update the local cache and
  /// sync with the backend when possible.
  Future<void> setFavourite(String id, {required bool isFavourite});

  /// Creates a new user-owned exercise via the backend and caches it locally.
  Future<Exercise> create({
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
  });

  /// Updates an existing user-owned exercise via the backend and local cache.
  Future<Exercise> update({
    required String id,
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
  });

  /// Deletes a user-owned exercise from the backend and local cache.
  Future<void> delete(String id);
}
