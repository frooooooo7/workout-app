import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../domain/models/training_stats.dart';
import '../stats_format.dart';
import 'stats_headlines.dart';
import 'stats_overview_card.dart';
import 'stats_sparkline.dart';

/// Pulpit: czy siła rośnie. Zdanie-wniosek i trzy najczęściej robione
/// ćwiczenia z mini-wykresem szacowanego 1RM.
class StatsStrengthSummaryCard extends StatelessWidget {
  const StatsStrengthSummaryCard({
    super.key,
    required this.snapshot,
    required this.onTap,
  });

  final TrainingStatsSnapshot snapshot;
  final VoidCallback onTap;

  static const _rows = 3;

  @override
  Widget build(BuildContext context) {
    final trends = StatsHeadlines.strengthTrends(snapshot.exercises);
    final headline = StatsHeadlines.strength(trends);
    final rows = [
      for (final t in trends)
        if (t.currentLabel.isNotEmpty) t,
    ].take(_rows).toList();
    final from = snapshot.progressFrom;

    return StatsOverviewCard(
      title: 'Siła',
      icon: Icons.trending_up_rounded,
      onTap: onTap,
      semanticsLabel: 'Siła, ${headline ?? 'szczegóły'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline ?? 'Za mało danych o progresie',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              height: 1.25,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            headline == null
                ? 'Progres liczymy od dwóch treningów tego samego ćwiczenia.'
                : 'Zmiana szacowanego maksimum od ${from.day} '
                      '${statsMonthsGenitive[from.month - 1]}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.3,
            ),
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
              StatsTrendRow(trend: rows[i]),
            ],
          ],
        ],
      ),
    );
  }
}

/// Wiersz ćwiczenia: nazwa z szacowanym 1RM, mini-wykres i zmiana. Ten sam
/// wiersz stoi na pulpicie i w liście na ekranie „Siła”.
class StatsTrendRow extends StatelessWidget {
  const StatsTrendRow({
    super.key,
    required this.trend,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(vertical: 11),
  });

  final StatsExerciseTrend trend;

  /// Zamiast „szac. 1RM …” (np. liczba treningów).
  final String? subtitle;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final direction = trend.direction;
    final flat = direction == 0;
    final color = switch (direction) {
      1 => AppColors.trendUp,
      -1 => AppColors.trendDown,
      _ => AppColors.textMuted,
    };
    final icon = switch (direction) {
      1 => Icons.arrow_upward_rounded,
      -1 => Icons.arrow_downward_rounded,
      _ => Icons.remove_rounded,
    };
    final change = trend.changeLabel;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trend.exercise.exerciseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle ?? trend.currentLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatsSparkline(values: trend.values, flat: flat, width: 76),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: change == null
                ? const SizedBox.shrink()
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (flat)
                          const Text(
                            'bez zmian',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else ...[
                          Icon(icon, size: 15, color: color),
                          const SizedBox(width: 2),
                          Text(
                            change,
                            maxLines: 1,
                            style: TextStyle(
                              color: color,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
