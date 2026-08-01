import 'package:flutter/material.dart';

import 'package:gym/core/theme/app_colors.dart';
import '../../../domain/models/monthly_training_history.dart';

/// Kompaktowe podsumowanie wybranego miesiąca: nazwa miesiąca u góry i do
/// czterech kluczowych statystyk w jednym rzędzie (siatka 2x2, gdy się nie
/// mieszczą). Statystyki pochodzą wyłącznie z [MonthlyTrainingStats] —
/// objętość treningowa jest pomijana, bo lista sesji nigdy jej nie zwraca
/// (zob. `TrainingHistoryRemoteDataSource`), więc
/// [MonthlyTrainingStats.totalVolumeKg] jest zawsze zerem.
class MonthlyStatsCard extends StatelessWidget {
  const MonthlyStatsCard({
    super.key,
    required this.focusedMonth,
    required this.stats,
  });

  final DateTime focusedMonth;
  final MonthlyTrainingStats stats;

  static const _fullMonthNames = [
    'Styczeń',
    'Luty',
    'Marzec',
    'Kwiecień',
    'Maj',
    'Czerwiec',
    'Lipiec',
    'Sierpień',
    'Wrzesień',
    'Październik',
    'Listopad',
    'Grudzień',
  ];

  static const _minCellWidth = 78.0;

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0m';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  List<_StatEntry> get _entries => [
        _StatEntry(
          icon: Icons.timer_outlined,
          color: AppColors.primaryVariant,
          value: _formatDuration(stats.totalDurationSec),
          label: 'Łączny czas',
        ),
        _StatEntry(
          icon: Icons.fitness_center_rounded,
          color: AppColors.success,
          value: '${stats.totalSessions}',
          label: stats.totalSessions == 1 ? 'Trening' : 'Treningi',
        ),
        _StatEntry(
          icon: Icons.format_list_bulleted_rounded,
          color: AppColors.strengthMedium,
          value: '${stats.totalExercises}',
          label: 'Ćwiczenia',
        ),
        _StatEntry(
          icon: Icons.layers_rounded,
          color: AppColors.primary,
          value: '${stats.totalSets}',
          label: stats.totalSets == 1 ? 'Seria' : 'Serie',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final monthName = _fullMonthNames[focusedMonth.month - 1];
    final entries = _entries;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$monthName ${focusedMonth.year}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final fitsSingleRow = constraints.maxWidth >= entries.length * _minCellWidth;
                return fitsSingleRow ? _StatsRow(entries: entries) : _StatsGrid(entries: entries);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _StatEntry {
  const _StatEntry({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
}

/// Jeden rząd statystyk z cienkimi, niepełnowysokimi separatorami między nimi.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.entries});

  final List<_StatEntry> entries;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      if (i != 0) {
        children.add(
          Container(
            width: 1,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: AppColors.border.withValues(alpha: 0.35),
          ),
        );
      }
      children.add(Expanded(child: _StatCell(entry: entries[i])));
    }
    return Row(children: children);
  }
}

/// Siatka 2xN bez separatorów — używana, gdy rząd by się nie zmieścił.
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.entries});

  final List<_StatEntry> entries;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i += 2) {
      final rowEntries = entries.sublist(i, (i + 2).clamp(0, entries.length));
      if (i != 0) rows.add(const SizedBox(height: 18));
      rows.add(
        Row(
          children: [
            for (var j = 0; j < rowEntries.length; j++) ...[
              if (j != 0) const SizedBox(width: 12),
              Expanded(child: _StatCell(entry: rowEntries[j])),
            ],
            if (rowEntries.length == 1) const Spacer(),
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.entry});

  final _StatEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: entry.color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(entry.icon, size: 15, color: entry.color),
        ),
        const SizedBox(height: 8),
        Text(
          entry.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          entry.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            height: 1.15,
          ),
        ),
      ],
    );
  }
}
