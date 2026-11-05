import '../models/training_session.dart';

/// Superserie w trakcie treningu: ćwiczenia jednej grupy robi się na
/// zmianę (A1, A2, A1…), a przerwa przychodzi dopiero po całej rundzie.
abstract final class SupersetRounds {
  /// Bloki ekranu treningu: pojedyncze ćwiczenie albo cała superseria
  /// (sąsiednie ćwiczenia z tą samą literą). Indeksy ćwiczeń w sesji.
  static List<List<int>> blocks(List<TrainingSessionExercise> exercises) {
    final result = <List<int>>[];
    for (var i = 0; i < exercises.length; i++) {
      final group = exercises[i].supersetGroup;
      if (group != null &&
          result.isNotEmpty &&
          exercises[result.last.last].supersetGroup == group) {
        result.last.add(i);
      } else {
        result.add([i]);
      }
    }
    return result;
  }

  /// Indeks bloku, w którym jest ćwiczenie [exerciseIndex].
  static int blockOf(List<List<int>> blocks, int exerciseIndex) {
    for (var b = 0; b < blocks.length; b++) {
      if (blocks[b].contains(exerciseIndex)) return b;
    }
    return blocks.isEmpty ? 0 : blocks.length - 1;
  }

  static int _done(TrainingSessionExercise exercise) =>
      exercise.sets.where((set) => set.completed).length;

  static bool _hasLeft(TrainingSessionExercise exercise) =>
      exercise.sets.any((set) => !set.completed);

  /// Ćwiczenie bloku, które jest teraz na kolei: to z najmniejszą liczbą
  /// zrobionych serii (przy remisie pierwsze), spośród tych z seriami do
  /// zrobienia. Gdy blok jest skończony — jego ostatnie ćwiczenie.
  static int focusOf(List<TrainingSessionExercise> exercises, List<int> block) {
    int? best;
    for (final index in block) {
      if (!_hasLeft(exercises[index])) continue;
      if (best == null || _done(exercises[index]) < _done(exercises[best])) {
        best = index;
      }
    }
    return best ?? block.last;
  }

  /// Bieżąca runda (od 1) i liczba rund bloku.
  static (int round, int total) roundOf(
    List<TrainingSessionExercise> exercises,
    List<int> block,
  ) {
    var total = 0;
    for (final index in block) {
      final count = exercises[index].sets.length;
      if (count > total) total = count;
    }
    final focus = focusOf(exercises, block);
    final round = _hasLeft(exercises[focus])
        ? _done(exercises[focus]) + 1
        : total;
    return (round.clamp(1, total < 1 ? 1 : total), total);
  }

  /// Po odhaczeniu serii w [exerciseIndex] (stan już po zmianie): czy
  /// należy się przerwa (koniec rundy albo zwykłe ćwiczenie) i ile trwa —
  /// w superserii liczy się przerwa ostatniego ćwiczenia grupy.
  /// `rest == false` — od razu następne ćwiczenie rundy ([next]).
  static ({bool rest, int? restSeconds, int next}) afterSet(
    List<TrainingSessionExercise> exercises,
    int exerciseIndex,
  ) {
    final exercise = exercises[exerciseIndex];
    if (exercise.supersetGroup == null) {
      return (
        rest: true,
        restSeconds: exercise.restSeconds,
        next: exerciseIndex,
      );
    }
    final block = blocks(
      exercises,
    ).firstWhere((b) => b.contains(exerciseIndex));
    if (block.length < 2) {
      return (
        rest: true,
        restSeconds: exercise.restSeconds,
        next: exerciseIndex,
      );
    }
    final round = _done(exercise);
    final roundDone = block.every((index) {
      final member = exercises[index];
      return _done(member) >= round || !_hasLeft(member);
    });
    final next = focusOf(exercises, block);
    return (
      rest: roundDone,
      restSeconds: exercises[block.last].restSeconds,
      next: next,
    );
  }
}
