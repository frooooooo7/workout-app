import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../domain/models/training_history_models.dart';
import '../session_details/session_details_formatters.dart';
import '../session_details/session_section_card.dart';

/// Zwięzła lista ćwiczeń: numer, nazwa, ukończone serie, najcięższa seria
/// i pasek objętości względem najmocniejszego ćwiczenia sesji.
/// Bez tabel z każdą serią — po szczegóły użytkownik idzie do historii.
class WorkoutSummaryExerciseList extends StatelessWidget {
  const WorkoutSummaryExerciseList({super.key, required this.exercises});

  final List<TrainingExerciseDetail> exercises;

  @override
  Widget build(BuildContext context) {
    final maxVolume = exercises.fold<double>(
      0,
      (max, e) => e.volumeKg > max ? e.volumeKg : max,
    );
    return SessionSectionCard(
      icon: Icons.fitness_center_rounded,
      title: 'Ćwiczenia',
      trailing: Text(
        '${exercises.length}',
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < exercises.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            _ExerciseRow(
              index: i,
              exercise: exercises[i],
              volumeShare: maxVolume > 0
                  ? exercises[i].volumeKg / maxVolume
                  : 0,
            ),
          ],
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.index,
    required this.exercise,
    required this.volumeShare,
  });

  final int index;
  final TrainingExerciseDetail exercise;

  /// Objętość ćwiczenia jako ułamek największej w sesji (0–1).
  final double volumeShare;

  @override
  Widget build(BuildContext context) {
    final completed = exercise.completedSetsCount;
    final total = exercise.workingSetsCount;
    final allDone = total > 0 && completed == total;
    final topSet = exercise.topSet;
    final volume = exercise.volumeKg;

    final trimmedNote = exercise.note?.trim() ?? '';
    final note = trimmedNote.isEmpty ? null : trimmedNote;
    final cardio = formatCardioSummary(exercise);
    final subtitleParts = <String>[
      exercise.tracking.isCardio
          ? '$completed/$total ${polishPlural(total, 'odcinek', 'odcinki', 'odcinków')}'
          : '$completed/$total ${polishPlural(total, 'seria', 'serie', 'serii')}',
      ?cardio,
      if (cardio == null && topSet != null)
        'top ${formatSetMetrics(topSet.actual)}',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: allDone
                  ? AppColors.success.withValues(alpha: 0.14)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(9),
            ),
            child: allDone
                ? const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppColors.success,
                  )
                : Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.exerciseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitleParts.join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    key: ValueKey('summary-exercise-note-$index'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(
                          Icons.sticky_note_2_outlined,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          note,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (volumeShare > 0) ...[
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: AppColors.surfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: volumeShare.clamp(0, 1),
                            child: const ColoredBox(
                              color: AppColors.primaryVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (volume > 0) ...[
            const SizedBox(width: 10),
            Text(
              formatVolumeKg(volume),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
