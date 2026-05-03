import '../domain/models/exercise.dart';

/// Shared in-memory filter logic applied to a list of [Exercise] objects.
///
/// Mirrors the server-side filter logic in `src/routes/exercises.ts` so that
/// the offline (SQLite) fallback produces the same results as the online API.
abstract final class ExerciseFilterUtils {
  static const _recentDays = 30;

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
        final cutoff =
            DateTime.now().subtract(const Duration(days: _recentDays));
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
      result = result.where((e) => e.muscles.contains(muscleGroup)).toList();
    }

    // ── Text search — name only (mirrors backend `lower(name) LIKE %q%`) ───
    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      result = result.where((e) => e.name.toLowerCase().contains(q)).toList();
    }

    return result;
  }
}
