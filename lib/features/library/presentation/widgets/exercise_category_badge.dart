import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/exercise.dart';

class ExerciseCategoryBadge extends StatelessWidget {
  const ExerciseCategoryBadge({super.key, required this.category});

  final ExerciseCategory category;

  Color get _color => switch (category) {
        ExerciseCategory.compound => AppColors.primaryVariant,
        ExerciseCategory.isolation => const Color(0xFF4DB6AC),
        ExerciseCategory.cardio => AppColors.success,
        ExerciseCategory.mobility => const Color(0xFFF59E0B),
        ExerciseCategory.plyometric => const Color(0xFFFF6B35),
        ExerciseCategory.calisthenics => const Color(0xFF6C8EFF),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.35)),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
