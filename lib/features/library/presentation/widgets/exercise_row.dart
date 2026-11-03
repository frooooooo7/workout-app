import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/models/exercise.dart';
import 'exercise_card_illustration.dart';

/// Wiersz listy biblioteki: miniatura ćwiczenia, nazwa, partia i sprzęt,
/// gwiazdka ulubionych. Długie przytrzymanie otwiera menu akcji.
class ExerciseRow extends StatelessWidget {
  const ExerciseRow({
    super.key,
    required this.exercise,
    this.onTap,
    this.onFavouriteTap,
    this.onMoreTap,
  });

  final Exercise exercise;
  final VoidCallback? onTap;
  final VoidCallback? onFavouriteTap;
  final VoidCallback? onMoreTap;

  static const double thumbSize = 56;
  static const double height = 72;

  /// „Klatka · Sztanga” — partia główna i sprzęt (gdy znany).
  static String subtitleFor(Exercise exercise) {
    final primary = exercise.workingMuscles.firstOrNull;
    final equipment = exercise.equipment;
    return [
      if (primary != null) primary.shortLabel,
      if (equipment != null) equipment.label,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = subtitleFor(exercise);
    return GestureDetector(
      onLongPress: onMoreTap,
      child: AppPressable(
        onTap: onTap,
        pressedScale: 0.98,
        child: Semantics(
          button: true,
          label: exercise.name,
          child: SizedBox(
            height: height,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: thumbSize,
                    height: thumbSize,
                    child: ExerciseCardIllustration(exercise: exercise),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tooltip(
                  message: exercise.isFavourite
                      ? 'Usuń z ulubionych'
                      : 'Dodaj do ulubionych',
                  child: GestureDetector(
                    onTap: onFavouriteTap,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        exercise.isFavourite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 22,
                        color: exercise.isFavourite
                            ? AppColors.record
                            : AppColors.textMuted,
                      ),
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
