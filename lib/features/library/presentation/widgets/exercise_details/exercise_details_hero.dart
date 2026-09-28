import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../data/exercise_image_uri.dart';
import '../../../domain/models/exercise.dart';
import '../exercise_category_badge.dart';

/// Ilustracja ćwiczenia na pełną szerokość, wtopiona w tło ekranu. Bez
/// zdjęcia — gradient w kolorze kategorii z ikoną.
class ExerciseDetailsHero extends StatelessWidget {
  const ExerciseDetailsHero({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final accent = ExerciseCategoryBadge.colorFor(exercise.category);
    final width = MediaQuery.sizeOf(context).width;
    final pixelWidth = (width * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(320, 1280);
    final provider = exerciseImageProvider(
      exercise.imageUrl,
      cacheWidth: pixelWidth,
    );

    final fallback = _HeroFallback(accent: accent);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (provider == null)
          fallback
        else
          Image(
            image: provider,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallback,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: child,
              );
            },
          ),
        // Przyciemnienie u góry pod przyciski i miękkie przejście w tło
        // ekranu u dołu, pod nazwę ćwiczenia.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.22, 0.6, 1],
              colors: [
                Color(0x99000000),
                Color(0x00000000),
                Color(0x000B0E14),
                AppColors.background,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.35, -0.2),
          radius: 1.1,
          colors: [
            accent.withValues(alpha: 0.28),
            accent.withValues(alpha: 0.06),
            AppColors.background,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: Center(
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.12),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 40),
            ],
          ),
          child: Icon(
            Icons.fitness_center_rounded,
            size: 44,
            color: accent.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

/// Okrągły, półprzezroczysty przycisk nad ilustracją.
class ExerciseHeroButton extends StatelessWidget {
  const ExerciseHeroButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = AppColors.textPrimary,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.background.withValues(alpha: 0.55),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween(begin: 0.7, end: 1.0).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(icon, key: ValueKey(icon), size: 21, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
