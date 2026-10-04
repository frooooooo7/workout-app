import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../training/presentation/widgets/session_details/session_details_formatters.dart';
import '../../../../training/presentation/widgets/stats/stats_format.dart';
import '../../../domain/models/exercise_stats.dart';
import 'exercise_progress_chart.dart' show formatExerciseHistoryDate;

/// „Historia”: poprzednie treningi z tym ćwiczeniem, od najnowszego, z każdą
/// serią. Dotknięcie wiersza otwiera szczegóły treningu.
class ExerciseHistorySection extends StatefulWidget {
  const ExerciseHistorySection({
    super.key,
    required this.history,
    this.onOpenSession,
  });

  /// Od najstarszego do najnowszego — jak w [ExerciseStats.history].
  final List<ExerciseSessionPoint> history;
  final ValueChanged<String>? onOpenSession;

  /// Tyle treningów widać przed „Pokaż wszystkie”.
  static const collapsedCount = 5;

  @override
  State<ExerciseHistorySection> createState() => _ExerciseHistorySectionState();
}

class _ExerciseHistorySectionState extends State<ExerciseHistorySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final newestFirst = widget.history.reversed.toList(growable: false);
    final canCollapse =
        newestFirst.length > ExerciseHistorySection.collapsedCount;
    final visible = _expanded || !canCollapse
        ? newestFirst
        : newestFirst.take(ExerciseHistorySection.collapsedCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border.withValues(alpha: 0.5),
            ),
          _HistoryRow(
            key: ValueKey('exercise-history-${visible[i].sessionId}-$i'),
            point: visible[i],
            onTap: widget.onOpenSession == null || visible[i].sessionId.isEmpty
                ? null
                : () => widget.onOpenSession!(visible[i].sessionId),
          ),
        ],
        if (canCollapse) ...[
          const SizedBox(height: 6),
          TextButton(
            key: const ValueKey('exercise-history-toggle'),
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryVariant,
              textStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(
              _expanded
                  ? 'Pokaż mniej'
                  : 'Pokaż wszystkie (${newestFirst.length})',
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({super.key, required this.point, this.onTap});

  final ExerciseSessionPoint point;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final local = point.date.toLocal();
    final summary = <String>[
      '${point.sets} ${polishPlural(point.sets, 'seria', 'serie', 'serii')}',
      if (point.volumeKg > 0) formatVolumeKg(point.volumeKg),
      if (point.estimatedOneRepMaxKg > 0)
        '1RM ${formatWeight((point.estimatedOneRepMaxKg * 2).round() / 2)} kg'
      else if (point.totalReps > 0)
        '${point.totalReps} powt.',
    ].join('  ·  ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DateBadge(date: local),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          point.sessionName.trim().isEmpty
                              ? formatExerciseHistoryDate(point.date)
                              : point.sessionName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (point.isRecord) const _RecordBadge(),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${statsWeekdaysLong[local.weekday - 1]}, '
                    '${formatExerciseHistoryDate(point.date)}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < point.setDetails.length; i++)
                        _SetChip(
                          set: point.setDetails[i],
                          best: i == point.bestSetIndex,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    summary,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (point.note != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.sticky_note_2_outlined,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            point.note!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 4, top: 10),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Text(
            '${date.day}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            statsMonthsShort[date.month - 1].toUpperCase(),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordBadge extends StatelessWidget {
  const _RecordBadge();

  @override
  Widget build(BuildContext context) {
    const color = AppColors.statAmber;
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, size: 12, color: color),
          SizedBox(width: 3),
          Text(
            'Rekord',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// `80 × 8`, `× 12` (bez ciężaru), rozgrzewka przygaszona z literą typu.
class _SetChip extends StatelessWidget {
  const _SetChip({required this.set, required this.best});

  final ExerciseHistorySet set;
  final bool best;

  @override
  Widget build(BuildContext context) {
    final warmup = !set.countsTowardStats;
    final weight = set.weightKg;
    final reps = set.reps;
    final text = switch ((weight, reps)) {
      (final w?, final r?) => '${formatWeight(w)} × $r',
      (final w?, null) => '${formatWeight(w)} kg',
      (null, final r?) => '× $r',
      (null, null) => '—',
    };
    final badge = set.type.badge;
    final color = best
        ? AppColors.primaryVariant
        : warmup
        ? AppColors.textMuted
        : AppColors.textPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: best
            ? AppColors.primary.withValues(alpha: 0.16)
            : AppColors.surfaceVariant.withValues(alpha: warmup ? 0.3 : 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: best
              ? AppColors.primaryVariant.withValues(alpha: 0.55)
              : AppColors.border.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null) ...[
            Text(
              badge,
              style: TextStyle(
                color: warmup ? AppColors.textMuted : AppColors.statOrange,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: best ? FontWeight.w700 : FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
