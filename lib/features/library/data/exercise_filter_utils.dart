import '../domain/exercise_search.dart';
import '../domain/models/exercise.dart';

/// Shared in-memory filter logic applied to a list of [Exercise] objects.
///
/// Tekst szukamy lokalnie ([ExerciseSearch]), bo SQLite nie zna polskich znaków.
abstract final class ExerciseFilterUtils {
  static const recentDays = 30;

  static List<Exercise> apply(
    List<Exercise> exercises, {
    MuscleGroup? muscleGroup,
    LibraryFilter? filter,
    String? query,
  }) {
    var result = exercises;

    // ── Chip filter ────────────────────────────────────────────────────────
    switch (filter) {
      case LibraryFilter.mine:
        result = result.where((e) => e.isMine).toList();
      case LibraryFilter.favourite:
        result = result.where((e) => e.isFavourite).toList();
      case LibraryFilter.recent:
        final cutoff = DateTime.now().subtract(
          const Duration(days: recentDays),
        );
        // Only include exercises with a known createdAt that is recent.
        result = result
            .where((e) => e.createdAt != null && e.createdAt!.isAfter(cutoff))
            .toList();
      case LibraryFilter.all:
      case null:
        break;
    }

    // ── Muscle group ────────────────────────────────────────────────────────
    if (muscleGroup != null && muscleGroup != MuscleGroup.all) {
      final matches = muscleGroup.filterMatches;
      result = result.where((e) => e.muscles.any(matches.contains)).toList();
    }

    // ── Text search — nazwa, mięśnie, bez polskich znaków, wg trafności ────
    if (query != null && query.trim().isNotEmpty) {
      result = ExerciseSearch.rank(result, query);
    }

    return result;
  }
}
