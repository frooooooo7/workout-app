import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/exercise_image_uri.dart';
import '../../domain/models/exercise.dart';

/// Ilustracja ćwiczenia wypełniająca rodzica; bez zdjęcia (albo gdy się nie
/// wczyta) — tło w kolorze partii mięśni z ikoną.
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
            width: 64,
            height: 64,
            colorFilter: ColorFilter.mode(
              _accentColor.withValues(alpha: 0.7),
              BlendMode.srcIn,
            ),
          )
        : Icon(
            _fallbackIcon,
            size: 48,
            color: _accentColor.withValues(alpha: 0.4),
          );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: _accentColor.withValues(alpha: 0.08),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.3, -0.2),
            radius: 1.15,
            colors: [
              _accentColor.withValues(alpha: 0.2),
              Colors.transparent,
            ],
          ),
        ),
        child: Center(child: _fallbackGraphic()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = exerciseThumbProvider(
      context,
      exercise.imageUrl,
      logicalSize: 200,
    );
    if (provider == null) return _placeholder();

    return Image(
      image: provider,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) => _placeholder(),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: child,
        );
      },
    );
  }
}
