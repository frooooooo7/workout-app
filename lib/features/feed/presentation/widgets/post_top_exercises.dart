import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/feed_post.dart';
import '../utils/feed_formatters.dart';

/// Kilka najważniejszych ćwiczeń posta, jedna linia na ćwiczenie.
class PostTopExercises extends StatelessWidget {
  const PostTopExercises({
    super.key,
    required this.exercises,
    required this.totalExercises,
    this.maxVisible = 3,
  });

  final List<TopExercise> exercises;
  final int totalExercises;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final visible = exercises.take(maxVisible).toList(growable: false);
    final rest = totalExercises - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final exercise in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryVariant,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    formatTopExerciseLine(exercise),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (rest > 0)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 1),
            child: Text(
              '+ ${formatExercisesCount(rest)}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
