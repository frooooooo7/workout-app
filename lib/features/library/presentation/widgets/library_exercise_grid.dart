import 'package:flutter/material.dart';

import '../../domain/models/exercise.dart';
import 'exercise_card.dart';

class LibraryExerciseGrid extends StatelessWidget {
  const LibraryExerciseGrid({
    super.key,
    required this.exercises,
    required this.onFavouriteTap,
    required this.onExerciseTap,
    required this.onMoreTap,
  });

  final List<Exercise> exercises;
  final Future<void> Function(Exercise) onFavouriteTap;
  final ValueChanged<Exercise> onExerciseTap;
  final ValueChanged<Exercise> onMoreTap;

  static const double _gutter = 16;
  static const double _spacing = 12;

  /// Docelowa szerokość kafelka — na tablecie mieści się więcej kolumn.
  static const double _targetTileWidth = 200;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - _gutter * 2;
        final columns = ((available + _spacing) / (_targetTileWidth + _spacing))
            .floor()
            .clamp(2, 6);
        final tileWidth = (available - _spacing * (columns - 1)) / columns;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: _spacing,
            mainAxisSpacing: _spacing,
            mainAxisExtent: ExerciseCard.heightFor(
              tileWidth,
              textScaler: textScaler,
            ),
          ),
          itemCount: exercises.length,
          itemBuilder: (context, index) {
            final exercise = exercises[index];
            return ExerciseCard(
              exercise: exercise,
              onTap: () => onExerciseTap(exercise),
              onFavouriteTap: () => onFavouriteTap(exercise),
              onMoreTap: () => onMoreTap(exercise),
            );
          },
        );
      },
    );
  }
}
