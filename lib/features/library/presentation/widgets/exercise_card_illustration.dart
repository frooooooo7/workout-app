import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/exercise.dart';

class ExerciseCardIllustration extends StatelessWidget {
  const ExerciseCardIllustration({super.key, required this.exercise});

  final Exercise exercise;

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
