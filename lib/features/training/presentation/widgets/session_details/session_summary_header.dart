import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/training_history_models.dart';
import 'session_details_formatters.dart';
import 'session_metrics_row.dart';
import 'session_status_chip.dart';

/// Nagłówek sesji — **jedyne** miejsce z metrykami całego treningu.
///
/// Sekcje poniżej (mapa mięśni, oś czasu, ćwiczenia) celowo ich nie powtarzają:
/// każda pokazuje wyłącznie to, czego nagłówek nie umie pokazać.
class SessionSummaryHeader extends StatelessWidget {
  const SessionSummaryHeader({super.key, required this.detail});

  final TrainingSessionDetail detail;

  @override
  Widget build(BuildContext context) {
    final note = detail.note?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                  border: Border.all(color: AppColors.primary, width: 1.6),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.plan.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatDateWithTime(detail.startedAt),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SessionStatusChip(status: detail.status),
            ],
          ),
          const SizedBox(height: 18),
          SessionMetricsRow(
            entries: [
              SessionMetricSpec(
                icon: Icons.access_time_rounded,
                value: formatDigitalDuration(detail.durationSec),
                label: 'Czas',
              ),
              SessionMetricSpec(
                icon: Icons.fitness_center_rounded,
                value: '${detail.exercises.length}',
                label: 'Ćwiczenia',
              ),
              SessionMetricSpec(
                icon: Icons.layers_rounded,
                value: '${detail.completedSetsCount}',
                label: 'Serie',
              ),
              SessionMetricSpec(
                icon: Icons.monitor_weight_outlined,
                value: formatVolumeKg(detail.totalVolumeKg),
                label: 'Objętość',
              ),
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    size: 15,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

