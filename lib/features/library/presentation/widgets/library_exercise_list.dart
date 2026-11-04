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
  });

  final List<Exercise> exercises;
  final Future<void> Function(Exercise) onFavouriteTap;
  final ValueChanged<Exercise> onExerciseTap;
  final ValueChanged<Exercise> onMoreTap;

  /// Historia treningów — daje „ostatni wynik” w wierszach.
  final ExerciseUsage usage;

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
