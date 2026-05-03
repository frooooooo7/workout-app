import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/exercise.dart';

class LibraryCategoryTabs extends StatelessWidget {
  const LibraryCategoryTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final MuscleGroup selected;
  final ValueChanged<MuscleGroup> onSelected;

  static const _visibleGroups = [
    MuscleGroup.all,
    MuscleGroup.chest,
    MuscleGroup.back,
    MuscleGroup.legs,
    MuscleGroup.shoulders,
    MuscleGroup.biceps,
    MuscleGroup.triceps,
    MuscleGroup.abs,
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _visibleGroups.length; i++)
              _CategorySegment(
                group: _visibleGroups[i],
                isSelected: _visibleGroups[i] == selected,
                showRightDivider: i < _visibleGroups.length - 1,
                onTap: () => onSelected(_visibleGroups[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategorySegment extends StatelessWidget {
  const _CategorySegment({
    required this.group,
    required this.isSelected,
    required this.showRightDivider,
    required this.onTap,
  });

  final MuscleGroup group;
  final bool isSelected;
  final bool showRightDivider;
  final VoidCallback onTap;

  IconData get _icon => switch (group) {
        MuscleGroup.all => Icons.grid_view_rounded,
        MuscleGroup.chest => Icons.fitness_center_rounded,
        MuscleGroup.back => Icons.accessibility_new_rounded,
        MuscleGroup.legs => Icons.directions_run_rounded,
        MuscleGroup.shoulders => Icons.sports_gymnastics_rounded,
        MuscleGroup.biceps => Icons.fitness_center_rounded,
        MuscleGroup.triceps => Icons.fitness_center_rounded,
        MuscleGroup.abs => Icons.self_improvement_rounded,
        _ => Icons.fitness_center_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primary : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primary.withValues(alpha: 0.2),
        highlightColor: AppColors.primary.withValues(alpha: 0.12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 76),
          decoration: BoxDecoration(
            border: showRightDivider
                ? const Border(
                    right: BorderSide(color: AppColors.border),
                  )
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _icon,
                size: 19,
                color:
                    isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                group.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
