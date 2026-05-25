import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class TrainingRestDayCard extends StatelessWidget {
  const TrainingRestDayCard({super.key, this.onCreatePlan});

  final VoidCallback? onCreatePlan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.self_improvement_rounded,
            color: AppColors.textMuted,
            size: 28,
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dzien odpoczynku',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Regeneracja to czesc treningu.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (onCreatePlan != null) ...[
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: onCreatePlan,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Dodaj plan'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
