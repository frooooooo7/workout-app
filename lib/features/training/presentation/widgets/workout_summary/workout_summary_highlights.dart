import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../domain/models/training_history_models.dart';
import '../session_details/session_details_formatters.dart';

/// Dwa wyróżnienia sesji: najcięższa seria i ćwiczenie z największą
/// objętością. Znika (razem z górnym odstępem), gdy w sesji nie ma żadnej
/// serii z ciężarem.
class WorkoutSummaryHighlights extends StatelessWidget {
  const WorkoutSummaryHighlights({super.key, required this.exercises});

  final List<TrainingExerciseDetail> exercises;

  @override
  Widget build(BuildContext context) {
    TrainingExerciseDetail? heaviestExercise;
    TrainingExerciseSetDetail? heaviestSet;
    TrainingExerciseDetail? topVolume;
    for (final exercise in exercises) {
      final top = exercise.topSet;
      if (top != null &&
          (heaviestSet == null ||
              (top.actual?.weightKg ?? 0) >
                  (heaviestSet.actual?.weightKg ?? 0))) {
        heaviestSet = top;
        heaviestExercise = exercise;
      }
      if (exercise.volumeKg > 0 &&
          (topVolume == null || exercise.volumeKg > topVolume.volumeKg)) {
        topVolume = exercise;
      }
    }
    if (heaviestSet == null || heaviestExercise == null || topVolume == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _HighlightTile(
                key: const ValueKey('summary-highlight-heaviest'),
                icon: Icons.emoji_events_rounded,
                accent: AppColors.strengthMedium,
                label: 'Najcięższa seria',
                value: formatSetMetrics(heaviestSet.actual),
                caption: heaviestExercise.exerciseName,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _HighlightTile(
                key: const ValueKey('summary-highlight-volume'),
                icon: Icons.local_fire_department_rounded,
                accent: const Color(0xFFA78BFA),
                label: 'Największa objętość',
                value: formatVolumeKg(topVolume.volumeKg),
                caption: topVolume.exerciseName,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({
    super.key,
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.07), AppColors.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accent),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
