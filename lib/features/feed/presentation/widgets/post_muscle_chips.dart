import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../library/domain/models/exercise.dart';

/// Trenowane partie jako małe chipy; nadmiar zwija się do „+N”.
class PostMuscleChips extends StatelessWidget {
  const PostMuscleChips({super.key, required this.muscles, this.maxVisible = 4});

  final List<MuscleGroup> muscles;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final visible = muscles.take(maxVisible).toList(growable: false);
    final rest = muscles.length - visible.length;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final muscle in visible) _Chip(label: muscle.shortLabel),
        if (rest > 0) _Chip(label: '+$rest'),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
