import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../library/domain/models/exercise.dart';
import '../../domain/models/custom_training_plan.dart';
import 'training_plan_detail_chips.dart';

class TrainingPlanCard extends StatelessWidget {
  const TrainingPlanCard({
    super.key,
    required this.plan,
    required this.onOpen,
    required this.onStart,
  });

  final CustomTrainingPlan plan;
  final VoidCallback onOpen;
  final Future<void> Function() onStart;

  int get _setCount => plan.exercises.fold(
        0,
        (sum, exercise) => sum + exercise.sets.length,
      );

  String get _exerciseLabel {
    final count = plan.exercises.length;
    if (count == 1) return '1 cwiczenie';
    return '$count cwiczenia';
  }

  String get _setLabel {
    if (_setCount == 1) return '1 seria';
    return '$_setCount serii';
  }

  String get _dayLabel {
    final count = plan.selectedDays.length;
    if (count == 1) return '1 dzien';
    return '$count dni';
  }

  String get _musclesLabel {
    final muscles = <MuscleGroup>{};
    for (final exercise in plan.exercises) {
      muscles.addAll(exercise.exercise.muscles);
    }
    final displayMuscles = muscles
        .where((muscle) => muscle != MuscleGroup.all)
        .toList();
    final visible = displayMuscles
        .take(3)
        .map((muscle) => muscle.label)
        .toList();
    if (visible.isEmpty) return 'Bez partii';
    final overflow = displayMuscles.length - visible.length;
    if (overflow > 0) return '${visible.join(', ')} +$overflow';
    return visible.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_dayLabel treningowe',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 0,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TrainingPlanDetailChip(label: _exerciseLabel),
                    const TrainingPlanDetailDot(),
                    TrainingPlanDetailChip(label: _setLabel),
                    const TrainingPlanDetailDot(),
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.textSecondary,
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    TrainingPlanDetailChip(label: _musclesLabel),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: onOpen,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Zobacz',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () async => onStart(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                  SizedBox(height: 2),
                  Text(
                    'Start',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
