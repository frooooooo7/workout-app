import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/training_history_models.dart';
import '../session_details/session_details_formatters.dart';
import '../session_details/session_section_card.dart';

/// Zwięzła lista ćwiczeń: numer, nazwa, ukończone serie i najcięższa seria.
/// Bez tabel z każdą serią — po szczegóły użytkownik idzie do historii.
class WorkoutSummaryExerciseList extends StatelessWidget {
  const WorkoutSummaryExerciseList({super.key, required this.exercises});

  final List<TrainingExerciseDetail> exercises;

  @override
  Widget build(BuildContext context) {
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
            _ExerciseRow(index: i, exercise: exercises[i]),
          ],
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.index, required this.exercise});

  final int index;
  final TrainingExerciseDetail exercise;

  @override
  Widget build(BuildContext context) {
    final completed = exercise.completedSetsCount;
    final total = exercise.sets.length;
    final allDone = total > 0 && completed == total;
    final topSet = exercise.topSet;
    final volume = exercise.volumeKg;

    final subtitleParts = <String>[
      '$completed/$total ${_setsLabel(total)}',
      if (topSet != null) 'top ${formatSetMetrics(topSet.actual)}',
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

  static String _setsLabel(int count) {
    if (count == 1) return 'seria';
    final lastDigit = count % 10;
    final lastTwo = count % 100;
    final isFew =
        lastDigit >= 2 && lastDigit <= 4 && !(lastTwo >= 12 && lastTwo <= 14);
    return isFew ? 'serie' : 'serii';
  }
}
