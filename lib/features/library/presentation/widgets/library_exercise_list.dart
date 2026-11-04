import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/exercise.dart';
import '../../domain/models/exercise_stats.dart';
import 'exercise_row.dart';

/// Lista ćwiczeń biblioteki w wierszach (miniatura, nazwa, partia · sprzęt).
class LibraryExerciseList extends StatelessWidget {
  const LibraryExerciseList({
    super.key,
    required this.exercises,
    required this.onFavouriteTap,
    required this.onExerciseTap,
    required this.onMoreTap,
    this.usage = ExerciseUsage.empty,
    this.selectedIds,
    this.selectionOrder = const [],
    this.existingIds = const {},
  });

  final List<Exercise> exercises;
  final Future<void> Function(Exercise) onFavouriteTap;
  final ValueChanged<Exercise> onExerciseTap;
  final ValueChanged<Exercise> onMoreTap;

  /// Historia treningów — daje „ostatni wynik” w wierszach.
  final ExerciseUsage usage;

  /// Zaznaczone ćwiczenia w trybie wyboru; `null` — zwykła lista.
  final Set<String>? selectedIds;

  /// Kolejność zaznaczania (id) — daje numery 1, 2, 3 w kółkach.
  final List<String> selectionOrder;

  /// Ćwiczenia, które już są w planie lub treningu („W planie”).
  final Set<String> existingIds;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 24),
      itemCount: exercises.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        thickness: 1,
        color: AppColors.border,
      ),
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        return ExerciseRow(
          exercise: exercise,
          selected: selectedIds?.contains(exercise.id),
          selectionNumber: selectionOrder.contains(exercise.id)
              ? selectionOrder.indexOf(exercise.id) + 1
              : null,
          inPlan: existingIds.contains(exercise.id),
          lastResult: usage.lastResultFor(exercise)?.label,
          lastDate: usage.lastResultFor(exercise)?.dateLabel(DateTime.now()),
          onTap: () => onExerciseTap(exercise),
          onFavouriteTap: () => onFavouriteTap(exercise),
          onMoreTap: () => onMoreTap(exercise),
        );
      },
    );
  }
}
