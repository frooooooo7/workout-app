import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../domain/models/training_stats.dart';
import '../stats_format.dart';
import '../stats_muscles_card.dart' show StatsBodyMap;
import 'stats_headlines.dart';
import 'stats_overview_card.dart';

/// Pulpit: mała mapa mięśni, zdanie o tym, co wymaga uwagi, i dwie
/// najmocniej trenowane partie (oraz pominięta, jeśli jest).
class StatsMusclesSummaryCard extends StatelessWidget {
  const StatsMusclesSummaryCard({
    super.key,
    required this.snapshot,
    required this.onTap,
  });

  final TrainingStatsSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = snapshot.muscles;
    if (m.isEmpty) return const SizedBox.shrink();
    final headline = StatsHeadlines.muscles(m, snapshot.recovery);
    final percents = roundedPercents([for (final r in m.regions) r.share]);
    final chips = <_Chip>[
      for (var i = 0; i < m.regions.length && i < 2; i++)
        _Chip(
          label:
              '${m.regions[i].region.label} '
              '${formatStatsPercent(percents[i], nonZero: m.regions[i].share > 0)}',
          color: AppColors.primary,
        ),
      if (m.neglected.isNotEmpty)
        _Chip(
          label:
              '${m.neglected.first.isCoarse ? m.neglected.first.label : m.neglected.first.shortLabel} 0%',
          color: AppColors.statAmber,
        ),
    ];

    return StatsOverviewCard(
      title: 'Mięśnie',
      icon: Icons.accessibility_new_rounded,
      onTap: onTap,
      semanticsLabel: 'Mięśnie, $headline',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          StatsBodyMap(
            bodyRoles: m.bodyRoles,
            neglected: m.neglected,
            figureHeight: 108,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final c in chips) c],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
