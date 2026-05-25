import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/training_summary_stats.dart';
import 'training_activity_summary_header.dart';
import 'training_summary_period_toggle.dart';
import 'training_summary_stat_tile.dart';

class TrainingActivitySummary extends StatefulWidget {
  const TrainingActivitySummary({super.key});

  @override
  State<TrainingActivitySummary> createState() =>
      _TrainingActivitySummaryState();
}

class _TrainingActivitySummaryState extends State<TrainingActivitySummary> {
  ActivitySummaryPeriod _period = ActivitySummaryPeriod.week;

  TrainingSummaryStats get _stats => _period == ActivitySummaryPeriod.week
      ? kTrainingSummaryWeek
      : kTrainingSummaryMonth;

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    final topRow = [
      TrainingSummaryStatTile(
        icon: Icons.fitness_center_rounded,
        iconColor: const Color(0xFF6C8EFF),
        value: '${stats.workouts}',
        unit: workoutCountLabelPlural(stats.workouts),
        label: 'Sesje',
        compact: false,
      ),
      TrainingSummaryStatTile(
        icon: Icons.timer_rounded,
        iconColor: const Color(0xFFFF6B35),
        value: '${stats.durationH}h ${stats.durationMin}min',
        unit: '',
        label: 'Czas aktywnosci',
        compact: false,
      ),
    ];

    final middleRow = [
      TrainingSummaryStatTile(
        icon: Icons.format_list_numbered_rounded,
        iconColor: AppColors.primaryVariant,
        value: '${stats.sets}',
        unit: 'serii',
        label: 'Serie',
        compact: true,
      ),
      TrainingSummaryStatTile(
        icon: Icons.repeat_rounded,
        iconColor: const Color(0xFF4DB6AC),
        value: '${stats.reps}',
        unit: 'powt.',
        label: 'Powtorzenia',
        compact: true,
      ),
      TrainingSummaryStatTile(
        icon: Icons.monitor_weight_rounded,
        iconColor: const Color(0xFFF59E0B),
        value: formatTrainingVolumeKg(stats.volumeKg),
        unit: 'kg',
        label: 'Laczny ciezar',
        compact: true,
      ),
    ];

    final bottomRow = [
      TrainingSummaryStatTile(
        icon: Icons.directions_run_rounded,
        iconColor: AppColors.success,
        value: stats.distanceKm.toStringAsFixed(1).replaceAll('.', ','),
        unit: 'km',
        label: 'Dystans',
        compact: false,
      ),
      TrainingSummaryStatTile(
        icon: Icons.local_fire_department_rounded,
        iconColor: const Color(0xFFFF6B35),
        value: formatTrainingVolumeKg(stats.caloriesKcal),
        unit: 'kcal',
        label: 'Spalone kalorie',
        compact: false,
      ),
    ];

    Widget rowTiles(List<TrainingSummaryStatTile> tiles) {
      return Row(
        children: [
          for (var i = 0; i < tiles.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == tiles.length - 1 ? 0 : 8),
                child: tiles[i],
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TrainingActivitySummaryHeader(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TrainingSummaryPeriodToggle(
                selected: _period,
                onChanged: (period) => setState(() => _period = period),
              ),
              const SizedBox(height: 16),
              rowTiles(topRow),
              const SizedBox(height: 8),
              rowTiles(middleRow),
              const SizedBox(height: 8),
              rowTiles(bottomRow),
            ],
          ),
        ),
      ],
    );
  }
}
