import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

class OngoingWorkoutProgressBar extends StatelessWidget {
  const OngoingWorkoutProgressBar({
    super.key,
    required this.currentIndex,
    required this.exerciseCount,
    required this.exerciseName,
    required this.onPrevious,
    required this.onNext,
    required this.onShowList,
  });

  final int currentIndex;
  final int exerciseCount;
  final String exerciseName;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onShowList;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              _NavigationButton(
                icon: Icons.chevron_left_rounded,
                onTap: onPrevious,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onShowList,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.format_list_bulleted_rounded,
                            color: AppColors.primaryVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${currentIndex + 1} / $exerciseCount',
                                  style: const TextStyle(
                                    color: AppColors.primaryVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  exerciseName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _NavigationButton(
                icon: Icons.chevron_right_rounded,
                onTap: onNext,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: exerciseCount == 0
                  ? 0
                  : (currentIndex + 1) / exerciseCount,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? AppColors.surfaceVariant : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 56,
          child: Icon(
            icon,
            color: onTap == null
                ? AppColors.textMuted
                : AppColors.textSecondary,
            size: 26,
          ),
        ),
      ),
    );
  }
}
