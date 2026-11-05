import '../models/custom_training_plan.dart';

/// Superserie w planie: sąsiednie ćwiczenia z tą samą literą grupy.
///
/// Wszystkie operacje zwracają nową listę z literami ponumerowanymi od
/// nowa (A, B, C… w kolejności planu), więc po usunięciu lub przesunięciu
/// ćwiczenia nie zostaje „dziura” ani grupa z jednym ćwiczeniem.
abstract final class SupersetGroups {
  static const _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  /// Czy ćwiczenie [index] można połączyć z następnym.
  static bool canLinkWithNext(List<PlanExercise> exercises, int index) {
    if (index < 0 || index >= exercises.length - 1) return false;
    final current = exercises[index].supersetGroup;
    return current == null || current != exercises[index + 1].supersetGroup;
  }

  /// Łączy ćwiczenie [index] z następnym. Gdy któreś jest już w grupie,
  /// drugie do niej dołącza (dwie grupy obok siebie zlewają się w jedną).
  static List<PlanExercise> linkWithNext(
    List<PlanExercise> exercises,
    int index,
  ) {
    if (!canLinkWithNext(exercises, index)) return exercises;
    final first = exercises[index].supersetGroup;
    final second = exercises[index + 1].supersetGroup;
    // Tymczasowy znacznik spoza A–Z; normalize nada właściwą literę.
    const marker = '#';
    final result = [
      for (final (i, exercise) in exercises.indexed)
        if (i == index ||
            i == index + 1 ||
            (first != null && exercise.supersetGroup == first) ||
            (second != null && exercise.supersetGroup == second))
          exercise.copyWith(supersetGroup: marker)
        else
          exercise,
    ];
    return normalize(result);
  }

  /// Rozdziela grupę [group] na zwykłe ćwiczenia.
  static List<PlanExercise> unlink(List<PlanExercise> exercises, String group) {
    return normalize([
      for (final exercise in exercises)
        exercise.supersetGroup == group
            ? exercise.copyWith(clearSupersetGroup: true)
            : exercise,
    ]);
  }

  /// Litery po kolei, tylko ciągłe grupy co najmniej dwóch ćwiczeń.
  static List<PlanExercise> normalize(List<PlanExercise> exercises) {
    final result = <PlanExercise>[];
    var nextLetter = 0;
    var i = 0;
    while (i < exercises.length) {
      final group = exercises[i].supersetGroup;
      var end = i + 1;
      if (group != null) {
        while (end < exercises.length &&
            exercises[end].supersetGroup == group) {
          end++;
        }
      }
      final isGroup = group != null && end - i >= 2 && nextLetter < 26;
      final letter = isGroup ? _letters[nextLetter++] : null;
      for (var k = i; k < end; k++) {
        final exercise = exercises[k];
        result.add(
          letter == null
              ? (exercise.supersetGroup == null
                    ? exercise
                    : exercise.copyWith(clearSupersetGroup: true))
              : (exercise.supersetGroup == letter
                    ? exercise
                    : exercise.copyWith(supersetGroup: letter)),
        );
      }
      i = end;
    }
    return result;
  }

  /// Czy [index] to ostatnie ćwiczenie swojej grupy (albo nie ma grupy) —
  /// po nim należy się przerwa.
  static bool endsRound<T>(
    List<T> items,
    int index,
    String? Function(T item) groupOf,
  ) {
    final group = groupOf(items[index]);
    if (group == null) return true;
    return index == items.length - 1 || groupOf(items[index + 1]) != group;
  }
}
