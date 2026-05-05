import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/exercise_image_uri.dart';
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

  Widget _fallbackGraphic() {
    final svgPath = _svgAsset;

    return svgPath != null
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
          );
  }

  Widget _patternBackground() {
    return ColoredBox(
      color: _accentColor.withValues(alpha: 0.08),
      child: DecoratedBox(
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
    );
  }

  Widget _photoErrorFallback() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _patternBackground(),
        Center(child: _fallbackGraphic()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = exerciseImageResolvedUri(exercise.imageUrl);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: SizedBox(
        height: 122,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (resolved != null)
              Image.network(
                resolved.toString(),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) =>
                    _photoErrorFallback(),
              )
            else
              _patternBackground(),
            if (resolved == null) Center(child: _fallbackGraphic()),
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
