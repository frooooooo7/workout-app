import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/custom_training_plan.dart';

class PlanDetailsStatsCard extends StatelessWidget {
  const PlanDetailsStatsCard({
    super.key,
    required this.plan,
  });

  final CustomTrainingPlan plan;

  @override
  Widget build(BuildContext context) {
    final totalExercises = plan.exercises.length;
    final totalSets = plan.exercises.fold<int>(0, (sum, ex) => sum + ex.sets.length);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatItem(icon: Icons.fitness_center, value: '$totalExercises', label: 'Ćwiczenia', color: AppColors.primary),
            Container(width: 1, height: 28, color: AppColors.border),
            _StatItem(icon: Icons.layers, value: '$totalSets', label: 'Serie razem', color: Colors.blueAccent),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
