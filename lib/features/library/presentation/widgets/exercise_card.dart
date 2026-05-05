import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/exercise.dart';
import 'exercise_card_illustration.dart';
import 'exercise_category_badge.dart';

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onTap,
    this.onFavouriteTap,
  });

  final Exercise exercise;
  final VoidCallback? onTap;
  final VoidCallback? onFavouriteTap;

  static const double _footerHeight = 46;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.primary.withValues(alpha: 0.07),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExerciseCardIllustration(exercise: exercise),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        exercise.muscles
                            .where((m) => m != MuscleGroup.all)
                            .map((m) => m.label)
                            .join(', '),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Container(height: 1, color: AppColors.border),
                      SizedBox(
                        height: _footerHeight,
                        child: Row(
                          children: [
                            ExerciseCategoryBadge(
                              category: exercise.category,
                            ),
                            if (exercise.isPendingSync) ...[
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Synchronizacja z serwerem',
                                child: Icon(
                                  Icons.cloud_sync_outlined,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            const Spacer(),
                            GestureDetector(
                              onTap: onFavouriteTap,
                              behavior: HitTestBehavior.opaque,
                              child: SizedBox(
                                width: 42,
                                height: _footerHeight,
                                child: Icon(
                                  exercise.isFavourite
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: exercise.isFavourite
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  size: 22,
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 22,
                              color: AppColors.border,
                            ),
                            GestureDetector(
                              onTap: onTap,
                              behavior: HitTestBehavior.opaque,
                              child: const SizedBox(
                                width: 42,
                                height: _footerHeight,
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
