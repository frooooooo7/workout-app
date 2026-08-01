import 'package:flutter/material.dart';

import 'package:gym/core/theme/app_colors.dart';
import '../../../domain/models/monthly_training_history.dart';

class MonthlySummaryFooter extends StatelessWidget {
  const MonthlySummaryFooter({
    super.key,
    required this.stats,
  });

  final MonthlyTrainingStats stats;

  static const _weekdayNames = [
    'Poniedziałek',
    'Wtorek',
    'Środa',
    'Czwartek',
    'Piątek',
    'Sobota',
    'Niedziela',
  ];

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '—';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    if (stats.totalSessions == 0) {
      return const SizedBox.shrink();
    }

    final topWeekdayName = stats.mostFrequentWeekday != null &&
            stats.mostFrequentWeekday! >= 1 &&
            stats.mostFrequentWeekday! <= 7
        ? _weekdayNames[stats.mostFrequentWeekday! - 1]
        : '—';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryInsight(
              label: 'Najczęstszy dzień',
              value: topWeekdayName,
              icon: Icons.calendar_today_rounded,
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: AppColors.border.withValues(alpha: 0.4),
          ),
          Expanded(
            child: _SummaryInsight(
              label: 'Średnia długość sesji',
              value: _formatDuration(stats.avgSessionDurationSec),
              icon: Icons.access_time_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryInsight extends StatelessWidget {
  const _SummaryInsight({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
