import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/training_history_models.dart';
import '../session_details/session_details_formatters.dart';

/// Cztery kluczowe liczby sesji w siatce 2×2 — duże wartości, małe etykiety.
/// To jedyne miejsce na ekranie podsumowania z metrykami całej sesji.
class WorkoutSummaryMetricsGrid extends StatelessWidget {
  const WorkoutSummaryMetricsGrid({super.key, required this.detail});

  final TrainingSessionDetail detail;

  @override
  Widget build(BuildContext context) {
    final tiles = <_MetricTileSpec>[
      _MetricTileSpec(
        icon: Icons.timer_outlined,
        value: formatDigitalDuration(detail.durationSec),
        label: 'Czas trwania',
        accent: AppColors.primaryVariant,
      ),
      _MetricTileSpec(
        icon: Icons.monitor_weight_outlined,
        value: formatVolumeKg(detail.totalVolumeKg),
        label: 'Objętość',
        accent: const Color(0xFFA78BFA),
      ),
      _MetricTileSpec(
        icon: Icons.layers_rounded,
        value: '${detail.completedSetsCount}',
        label: _setsLabel(detail.completedSetsCount),
        accent: AppColors.success,
      ),
      _MetricTileSpec(
        icon: Icons.fitness_center_rounded,
        value: '${detail.exercises.length}',
        label: _exercisesLabel(detail.exercises.length),
        accent: AppColors.strengthMedium,
      ),
    ];

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _MetricTile(spec: tiles[0])),
            const SizedBox(width: 10),
            Expanded(child: _MetricTile(spec: tiles[1])),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _MetricTile(spec: tiles[2])),
            const SizedBox(width: 10),
            Expanded(child: _MetricTile(spec: tiles[3])),
          ],
        ),
      ],
    );
  }

  static String _setsLabel(int count) {
    if (count == 1) return 'Ukończona seria';
    return 'Ukończone serie';
  }

  static String _exercisesLabel(int count) {
    if (count == 1) return 'Ćwiczenie';
    return 'Ćwiczenia';
  }
}

class _MetricTileSpec {
  const _MetricTileSpec({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.spec});

  final _MetricTileSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: spec.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(spec.icon, size: 18, color: spec.accent),
          ),
          const SizedBox(height: 14),
          Text(
            spec.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            spec.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
