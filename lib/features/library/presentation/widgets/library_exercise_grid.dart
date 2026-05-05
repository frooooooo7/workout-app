import 'package:flutter/material.dart';

import '../../domain/models/exercise.dart';
import 'exercise_card.dart';

class LibraryExerciseGrid extends StatelessWidget {
  const LibraryExerciseGrid({
    super.key,
    required this.exercises,
    required this.onFavouriteTap,
  });

  final List<Exercise> exercises;
  final Future<void> Function(Exercise) onFavouriteTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.86,
      ),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        return ExerciseCard(
          exercise: exercise,
          onTap: () {},
          onFavouriteTap: () => onFavouriteTap(exercise),
        );
      },
    );
  }
}
