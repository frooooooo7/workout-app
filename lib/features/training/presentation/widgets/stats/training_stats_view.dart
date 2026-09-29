import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../domain/models/training_stats.dart';
import '../../bloc/training_stats_cubit.dart';
import 'stats_activity_card.dart';
import 'stats_exercise_progress_card.dart';
import 'stats_habits_card.dart';
import 'stats_kpi_grid.dart';
import 'stats_muscles_card.dart';
import 'stats_range_selector.dart';
import 'stats_records_card.dart';
import 'stats_states.dart';
import 'stats_top_exercises_card.dart';
import 'stats_trend_chart_card.dart';

/// Treść statystyk: zakres, kafelki i karty z wykresami. Wymaga
/// [TrainingStatsCubit] w kontekście.
class TrainingStatsView extends StatelessWidget {
  const TrainingStatsView({super.key, this.onStartWorkout});

  /// Przycisk w pustym stanie (brak historii).
  final VoidCallback? onStartWorkout;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainingStatsCubit, TrainingStatsState>(
      builder: (context, state) {
        final cubit = context.read<TrainingStatsCubit>();
        final snapshot = state.snapshot;

        final List<Widget> content;
        if (snapshot == null && state.failed) {
          content = [StatsErrorState(onRetry: cubit.load)];
        } else if (snapshot == null) {
          content = const [StatsSkeleton()];
        } else if (!snapshot.hasHistory) {
          content = [StatsEmptyState(onStartWorkout: onStartWorkout)];
        } else {
          content = _sections(context, snapshot, cubit);
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () {
            HapticFeedback.lightImpact();
            return cubit.load();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pageGutter,
              AppSpacing.xxs,
              AppSpacing.pageGutter,
              AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              if (snapshot?.hasHistory ?? true) ...[
                StatsRangeSelector(
                  selected: state.range,
                  onChanged: cubit.selectRange,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              ...content,
            ],
          ),
        );
      },
    );
  }

  List<Widget> _sections(
    BuildContext context,
    TrainingStatsSnapshot snapshot,
    TrainingStatsCubit cubit,
  ) {
    const gap = SizedBox(height: AppSpacing.md);
    return [
      StatsKpiGrid(snapshot: snapshot),
      if (snapshot.isEmpty) ...[
        gap,
        StatsEmptyRangeNotice(
          onShowAll: snapshot.range == StatsRange.all
              ? null
              : () => cubit.selectRange(StatsRange.all),
        ),
      ] else ...[
        gap,
        StatsTrendChartCard(snapshot: snapshot),
      ],
      // Rekordy wszech czasów i heatmapa mają sens także przy pustym zakresie.
      gap,
      StatsRecordsCard(
        records: snapshot.records,
        bests: snapshot.bests,
        now: snapshot.activity.today,
      ),
      if (!snapshot.isEmpty) ...[
        gap,
        StatsMusclesCard(muscles: snapshot.muscles),
        gap,
        StatsExerciseProgressCard(
          exercises: snapshot.exercises,
          progressFrom: snapshot.progressFrom,
        ),
        gap,
        StatsTopExercisesCard(exercises: snapshot.exercises),
      ],
      gap,
      StatsActivityCard(activity: snapshot.activity),
      if (!snapshot.isEmpty) ...[gap, StatsHabitsCard(habits: snapshot.habits)],
    ];
  }
}
