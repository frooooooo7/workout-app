import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/models/exercise.dart';
import 'exercise_card_illustration.dart';
import 'exercise_category_badge.dart';

/// Kafelek ćwiczenia w siatce biblioteki: ilustracja 4:3 z kategorią
/// i gwiazdką, pod nią nazwa i partie mięśni. Wysokość wynika z szerokości
/// ([heightFor]) — stałe proporcje kafelka przepełniały się na wąskich
/// telefonach.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onTap,
    this.onFavouriteTap,
    this.onMoreTap,
  });

  final Exercise exercise;
  final VoidCallback? onTap;
  final VoidCallback? onFavouriteTap;

  /// Menu akcji — przycisk „⋯” i długie przytrzymanie kafelka.
  final VoidCallback? onMoreTap;

  static const double _radius = 18;
  static const double _infoHeight = 78;

  /// Wysokość kafelka o szerokości [width] (ilustracja 4:3 + opis).
  static double heightFor(double width, {TextScaler? textScaler}) {
    final scale = textScaler?.scale(1) ?? 1;
    return width * 3 / 4 + _infoHeight * scale;
  }

  @override
  Widget build(BuildContext context) {
    final muscles = exercise.workingMuscles;

    return GestureDetector(
      onLongPress: onMoreTap,
      child: AppPressable(
        onTap: onTap,
        pressedScale: 0.97,
        child: Semantics(
          button: true,
          label: exercise.name,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ExerciseCardIllustration(exercise: exercise),
                      // Delikatne przyciemnienie krawędzi pod nakładki.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0, 0.3, 0.75, 1],
                            colors: [
                              Color(0x66000000),
                              Color(0x00000000),
                              Color(0x00000000),
                              Color(0x33000000),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 48,
                        child: Row(
                          children: [
                            Flexible(
                              child: _CategoryPill(category: exercise.category),
                            ),
                            if (exercise.isPendingSync) ...[
                              const SizedBox(width: 4),
                              const Tooltip(
                                message: 'Synchronizacja z serwerem',
                                child: _GlassCircle(
                                  size: 22,
                                  child: Icon(
                                    Icons.cloud_sync_outlined,
                                    size: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: _FavouriteButton(
                          isFavourite: exercise.isFavourite,
                          onTap: onFavouriteTap,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 2, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exercise.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Spacer(),
                              if (muscles.isNotEmpty)
                                _MuscleLine(muscles: muscles),
                            ],
                          ),
                        ),
                        if (onMoreTap != null)
                          Tooltip(
                            message: 'Więcej',
                            child: GestureDetector(
                              onTap: onMoreTap,
                              behavior: HitTestBehavior.opaque,
                              child: const SizedBox(
                                width: 34,
                                height: 34,
                                child: Icon(
                                  Icons.more_vert_rounded,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                              ),
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
      ),
    );
  }
}

/// Mięsień główny z kropką akcentu + liczba wspomagających.
class _MuscleLine extends StatelessWidget {
  const _MuscleLine({required this.muscles});

  final List<MuscleGroup> muscles;

  @override
  Widget build(BuildContext context) {
    final extra = muscles.length - 1;
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.primaryVariant,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            muscles.first.shortLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (extra > 0) ...[
          const SizedBox(width: 6),
          Text(
            '+$extra',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.category});

  final ExerciseCategory category;

  @override
  Widget build(BuildContext context) {
    final color = ExerciseCategoryBadge.colorFor(category);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              category.label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavouriteButton extends StatelessWidget {
  const _FavouriteButton({required this.isFavourite, required this.onTap});

  final bool isFavourite;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isFavourite ? 'Usuń z ulubionych' : 'Dodaj do ulubionych',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // Pole dotyku 44 px wokół widocznego kółka 30 px.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: _GlassCircle(
              size: 30,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: Tween(begin: 0.6, end: 1.0).animate(animation),
                  child: child,
                ),
                child: Icon(
                  isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
                  key: ValueKey(isFavourite),
                  size: 17,
                  color: isFavourite
                      ? AppColors.primaryVariant
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  const _GlassCircle({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.72),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
