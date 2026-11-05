import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../domain/models/training_stats.dart';
import '../../personal_record_format.dart';
import '../stats_format.dart';
import 'stats_headlines.dart';
import 'stats_overview_card.dart';

/// Pulpit: ile rekordów padło w okresie i dwa najnowsze. Trofeum jest złote
/// tylko tu i na liście rekordów — to jedyne miejsce, gdzie znaczy „rekord”.
class StatsRecordsSummaryCard extends StatelessWidget {
  const StatsRecordsSummaryCard({
    super.key,
    required this.snapshot,
    required this.onTap,
  });

  final TrainingStatsSnapshot snapshot;
  final VoidCallback onTap;

  static const _rows = 2;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final delta = s.previousRecordsCount == null
        ? null
        : StatsDelta.absolute(s.recordsCount, s.previousRecordsCount!);
    final rows = s.records.take(_rows).toList();
    final headline = StatsHeadlines.records(s.recordsCount);

    return StatsOverviewCard(
      title: 'Rekordy',
      icon: Icons.emoji_events_outlined,
      onTap: onTap,
      semanticsLabel: 'Rekordy, $headline',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  headline,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (delta != null && delta.direction != 0) ...[
                const SizedBox(width: 8),
                Icon(
                  delta.direction > 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 16,
                  color: delta.direction > 0
                      ? AppColors.trendUp
                      : AppColors.trendDown,
                ),
                Text(
                  delta.text.replaceFirst(RegExp('^[+−]'), ''),
                  style: TextStyle(
                    color: delta.direction > 0
                        ? AppColors.trendUp
                        : AppColors.trendDown,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          if (rows.isEmpty && s.bests.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Najlepsze wyniki ${s.bests.length} ćwiczeń są w szczegółach.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
              _Row(record: rows[i], now: s.activity.today),
            ],
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.record, required this.now});

  final PersonalRecord record;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.record.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 19,
              color: AppColors.record,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.exerciseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatStatsRelativeDay(record.date.toLocal(), now),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            personalRecordValue(record),
            style: const TextStyle(
              color: AppColors.record,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
