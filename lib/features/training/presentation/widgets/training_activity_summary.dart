import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/polish_plural.dart';
import '../../domain/models/training_summary_stats.dart';
import '../bloc/training_summary_cubit.dart';
import 'training_activity_summary_header.dart';
import 'training_summary_period_toggle.dart';
import 'training_summary_stat_tile.dart';

/// Podsumowanie tygodnia / miesiąca. Wymaga [TrainingSummaryCubit]
/// w kontekście.
class TrainingActivitySummary extends StatefulWidget {
  const TrainingActivitySummary({super.key});

  @override
  State<TrainingActivitySummary> createState() =>
      _TrainingActivitySummaryState();
}

class _TrainingActivitySummaryState extends State<TrainingActivitySummary> {
  ActivitySummaryPeriod _period = ActivitySummaryPeriod.week;

  @override
  Widget build(BuildContext context) {
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
              BlocBuilder<TrainingSummaryCubit, TrainingSummaryState>(
                builder: (context, state) {
                  final summary = state.summary;
                  if (summary == null && state.failed) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Nie udało się policzyć statystyk.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return _StatsGrid(
                    stats: summary?.of(_period),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  /// `null` — trwa pierwsze wczytanie.
  final TrainingPeriodStats? stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    String value(String Function(TrainingPeriodStats s) format) =>
        s == null ? '—' : format(s);
    String unit(String Function(TrainingPeriodStats s) format) =>
        s == null ? '' : format(s);

    final rows = [
      [
        TrainingSummaryStatTile(
          icon: Icons.fitness_center_rounded,
          iconColor: const Color(0xFF6C8EFF),
          value: value((s) => '${s.workouts}'),
          unit: unit(
            (s) => polishPlural(s.workouts, 'trening', 'treningi', 'treningów'),
          ),
          label: 'Sesje',
          compact: false,
        ),
        TrainingSummaryStatTile(
          icon: Icons.timer_rounded,
          iconColor: const Color(0xFFFF6B35),
          value: value((s) => formatDuration(s.durationSec)),
          unit: '',
          label: 'Czas treningów',
          compact: false,
        ),
      ],
      [
        TrainingSummaryStatTile(
          icon: Icons.format_list_numbered_rounded,
          iconColor: AppColors.primaryVariant,
          value: value((s) => formatTrainingVolumeKg(s.completedSets)),
          unit: unit(
            (s) => polishPlural(s.completedSets, 'seria', 'serie', 'serii'),
          ),
          label: 'Ukończone serie',
          compact: false,
        ),
        TrainingSummaryStatTile(
          icon: Icons.repeat_rounded,
          iconColor: const Color(0xFF4DB6AC),
          value: value((s) => formatTrainingVolumeKg(s.reps)),
          unit: unit((_) => 'powt.'),
          label: 'Powtórzenia',
          compact: false,
        ),
      ],
      [
        TrainingSummaryStatTile(
          icon: Icons.monitor_weight_rounded,
          iconColor: const Color(0xFFF59E0B),
          value: value((s) => formatTrainingVolumeKg(s.volumeKg.round())),
          unit: unit((_) => 'kg'),
          label: 'Łączny ciężar',
          compact: false,
        ),
        TrainingSummaryStatTile(
          icon: Icons.view_list_rounded,
          iconColor: AppColors.success,
          value: value((s) => '${s.distinctExercises}'),
          unit: unit(
            (s) => polishPlural(
              s.distinctExercises,
              'ćwiczenie',
              'ćwiczenia',
              'ćwiczeń',
            ),
          ),
          label: 'Różne ćwiczenia',
          compact: false,
        ),
      ],
    ];

    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < rows[r].length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == rows[r].length - 1 ? 0 : 8,
                    ),
                    child: rows[r][i],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
