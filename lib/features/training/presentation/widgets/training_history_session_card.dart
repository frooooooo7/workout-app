import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../domain/models/training_history_models.dart';

class TrainingHistorySessionCard extends StatelessWidget {
  const TrainingHistorySessionCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  final TrainingSessionListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.plan.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${formatDuration(item.durationSec)} · ${item.exercisesCount} ćw. · ${item.completedSetsCount} serii',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.progressHighlight?.label ?? 'Brak progresu',
                    style: TextStyle(
                      color: item.progressHighlight == null
                          ? AppColors.textMuted
                          : AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (item.hasNote)
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    color: AppColors.textSecondary,
                    size: 17,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

