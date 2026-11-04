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
    this.lastResult,
    this.lastDate,
    this.selected,
  });

  final Exercise exercise;

  /// Ostatni wynik w treningu („80 kg × 5”); `null` — nie robiono.
  final String? lastResult;

  /// Kiedy to było („pon.”, „28 paź”), pod wynikiem.
  final String? lastDate;

  /// Tryb wyboru: `true` — zaznaczone, `false` — nie; `null` — zwykły wiersz
  /// (z gwiazdką ulubionych).
  final bool? selected;
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
          selected: selected ?? false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: height),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
                if (lastResult != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            lastResult!,
                            textAlign: TextAlign.end,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSubtle,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (lastDate != null)
                            Text(
                              lastDate!,
                              maxLines: 1,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (selected != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, right: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected! ? AppColors.primary : Colors.transparent,
                        border: Border.all(
                          color: selected! ? AppColors.primary : AppColors.textMuted,
                          width: 1.5,
                        ),
                      ),
                      child: selected!
                          ? const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: AppColors.onPrimary,
                            )
                          : null,
                    ),
                  )
                else
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
      ),
    );
  }
}
