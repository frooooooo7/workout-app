import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/app_pressable.dart';
import '../../../domain/models/training_session.dart';
import 'exercise_thumb.dart';
import 'workout_colors.dart';

/// Karta „Następne”: kolejne ćwiczenie z planem serii i ostatnim wynikiem.
/// Dotknięcie przechodzi do niego.
class NextExerciseCard extends StatelessWidget {
  const NextExerciseCard({
    super.key,
    required this.exercise,
    required this.onTap,
    this.lastResult,
  });

  final TrainingSessionExercise exercise;

  /// Najlepsza seria z poprzedniego treningu (`26 × 10`).
  final String? lastResult;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = [
      ?nextExercisePlan(exercise),
      if (lastResult != null) 'ostatnio $lastResult',
    ].join(' · ');
    return Semantics(
      button: true,
      child: AppPressable(
        onTap: onTap,
        pressedScale: 0.98,
        child: Container(
          key: const Key('next-exercise-card'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: WorkoutColors.nextCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: WorkoutColors.nextCardBorder),
          ),
          child: Row(
            children: [
              ExerciseThumb(
                imageUrl: exercise.exerciseImageUrl,
                size: 44,
                radius: 12,
                opacity: 0.85,
                cardio: exercise.tracking.isCardio,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NASTĘPNE',
                      style: TextStyle(
                        color: WorkoutColors.textFaint,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.84,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      exercise.exerciseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `3 × 10` (serie robocze × planowane powtórzenia, gdy wszystkie takie same)
/// albo `3 serie`; `null` bez serii roboczych.
String? nextExercisePlan(TrainingSessionExercise exercise) {
  final working = [
    for (final set in exercise.sets)
      if (set.countsTowardStats) set,
  ];
  if (working.isEmpty) return null;
  if (exercise.tracking.isCardio) return cardioSegmentsLabel(working.length);
  final reps = working.map((set) => set.plannedReps.trim()).toSet();
  final count = working.length;
  if (reps.length == 1 && reps.first.isNotEmpty) {
    return '$count × ${reps.first}';
  }
  return '$count ${_setsWord(count)}';
}

String _setsWord(int count) {
  if (count == 1) return 'seria';
  final lastTwo = count % 100;
  final last = count % 10;
  if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) return 'serie';
  return 'serii';
}
