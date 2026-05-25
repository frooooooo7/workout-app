import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class TrainingActiveSessionCard extends StatelessWidget {
  const TrainingActiveSessionCard({
    super.key,
    required this.planName,
    required this.onResume,
  });

  final String planName;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aktywna sesja',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  planName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onResume, child: const Text('Wznow')),
        ],
      ),
    );
  }
}
