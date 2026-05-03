import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/exercise.dart';

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
              _ExerciseIllustration(exercise: exercise),
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
                      Container(
                        height: 1,
                        color: AppColors.border,
                      ),
                      SizedBox(
                        height: _footerHeight,
                        child: Row(
                          children: [
                            _CategoryBadge(category: exercise.category),
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

class _ExerciseIllustration extends StatelessWidget {
  const _ExerciseIllustration({required this.exercise});

  final Exercise exercise;

  // Returns an SVG asset path if available, null otherwise.
  String? get _svgAsset => switch (exercise.muscles.firstOrNull) {
        MuscleGroup.chest => 'assets/icons/muscle_chest.svg',
        _ => null,
      };

  IconData get _fallbackIcon => switch (exercise.muscles.firstOrNull) {
        MuscleGroup.back => Icons.accessibility_new_rounded,
        MuscleGroup.legs => Icons.directions_run_rounded,
        MuscleGroup.shoulders => Icons.sports_gymnastics_rounded,
        MuscleGroup.abs => Icons.self_improvement_rounded,
        MuscleGroup.glutes => Icons.directions_run_rounded,
        _ => Icons.fitness_center_rounded,
      };

  Color get _accentColor => switch (exercise.muscles.firstOrNull) {
        MuscleGroup.chest => AppColors.primaryVariant,
        MuscleGroup.back => const Color(0xFF4DB6AC),
        MuscleGroup.legs => AppColors.success,
        MuscleGroup.shoulders => const Color(0xFFF59E0B),
        MuscleGroup.biceps => const Color(0xFF6C8EFF),
        MuscleGroup.triceps => AppColors.primaryVariant,
        MuscleGroup.abs => const Color(0xFF4DB6AC),
        MuscleGroup.glutes => AppColors.success,
        _ => AppColors.primary,
      };

  @override
  Widget build(BuildContext context) {
    final svgPath = _svgAsset;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        height: 122,
        color: _accentColor.withValues(alpha: 0.08),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.3, -0.2),
                    radius: 1.15,
                    colors: [
                      _accentColor.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: svgPath != null
                  ? SvgPicture.asset(
                      svgPath,
                      width: 72,
                      height: 72,
                      colorFilter: ColorFilter.mode(
                        _accentColor.withValues(alpha: 0.7),
                        BlendMode.srcIn,
                      ),
                    )
                  : Icon(
                      _fallbackIcon,
                      size: 52,
                      color: _accentColor.withValues(alpha: 0.35),
                    ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

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
