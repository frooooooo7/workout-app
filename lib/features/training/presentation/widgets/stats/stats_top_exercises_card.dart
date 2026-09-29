import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../../core/widgets/app_pressable.dart';
import '../../../domain/models/training_stats.dart';
import '../session_details/session_section_card.dart';
import 'stats_format.dart';
import 'stats_navigation.dart';

/// Pięć najczęściej wykonywanych ćwiczeń w zakresie.
class StatsTopExercisesCard extends StatelessWidget {
  const StatsTopExercisesCard({super.key, required this.exercises});

  /// Od najczęstszego (tak zwraca kalkulator).
  final List<ExerciseProgress> exercises;

  static const _maxRows = 5;

  @override
  Widget build(BuildContext context) {
    final top = exercises.take(_maxRows).toList(growable: false);
    final leader = top.isEmpty ? 0 : top.first.sessions;
    return SessionSectionCard(
      icon: Icons.format_list_numbered_rounded,
      title: 'Najczęstsze ćwiczenia',
      child: top.isEmpty
          ? const Text(
              'Brak ćwiczeń w tym okresie.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < top.length; i++)
                  _ExerciseRow(
                    rank: i + 1,
                    exercise: top[i],
                    fill: leader > 0 ? top[i].sessions / leader : 0,
                  ),
              ],
            ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.rank,
    required this.exercise,
    required this.fill,
  });

  final int rank;
  final ExerciseProgress exercise;
  final double fill;

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    final canOpen = canOpenStatsExercise(e.exerciseId);
    final details =
        '${e.sessions} ${polishPlural(e.sessions, 'trening', 'treningi', 'treningów')}'
        ' · ${e.sets} ${polishPlural(e.sets, 'seria', 'serie', 'serii')}';
    final volume = e.volumeKg > 0 ? formatStatsVolume(e.volumeKg) : null;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank == 1
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                color: rank == 1
                    ? AppColors.primaryVariant
                    : AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        e.exerciseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    if (volume != null)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: volume.value,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(
                              text: ' ${volume.unit}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      )
                    else
                      const Text(
                        'masa ciała',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  details,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: fill.clamp(0, 1),
                    minHeight: 3,
                    backgroundColor: AppColors.chartTrack,
                    valueColor: const AlwaysStoppedAnimation(
                      AppColors.primaryVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (canOpen) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: canOpen,
      container: true,
      excludeSemantics: true,
      onTap: canOpen ? () => openStatsExercise(context, e.exerciseId) : null,
      label: [
        '$rank. ${e.exerciseName}',
        details,
        if (volume != null) '${volume.value} ${volume.unit}',
      ].join(', '),
      child: canOpen
          ? AppPressable(
              pressedScale: 0.98,
              onTap: () => openStatsExercise(context, e.exerciseId),
              child: row,
            )
          : row,
    );
  }
}
