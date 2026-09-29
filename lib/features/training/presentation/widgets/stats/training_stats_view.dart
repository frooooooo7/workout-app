import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../domain/models/training_stats.dart';
import '../../bloc/training_stats_cubit.dart';
import '../workout_summary/staggered_reveal.dart';
import 'stats_activity_card.dart';
import 'stats_date_range_picker.dart';
import 'stats_exercise_progress_card.dart';
import 'stats_goal_card.dart';
import 'stats_habits_card.dart';
import 'stats_insights_card.dart';
import 'stats_kpi_grid.dart';
import 'stats_muscles_card.dart';
import 'stats_range_selector.dart';
import 'stats_recovery_card.dart';
import 'stats_records_card.dart';
import 'stats_rep_ranges_card.dart';
import 'stats_session_records_card.dart';
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
          // Kolumna zamiast ListView: ListView niszczy karty poza ekranem, więc
          // po powrocie traciłyby stan (wybrane ćwiczenie, zaznaczony dzień)
          // i animowały się od nowa. Kart jest kilka — budujemy wszystkie.
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pageGutter,
              AppSpacing.xxs,
              AppSpacing.pageGutter,
              AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (snapshot?.hasHistory ?? true) ...[
                  StatsRangeSelector(
                    selected: state.range,
                    customRange: state.customRange,
                    onChanged: cubit.selectRange,
                    onPickCustom: () => _pickCustomRange(context, state),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                ...content,
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickCustomRange(
    BuildContext context,
    TrainingStatsState state,
  ) async {
    final cubit = context.read<TrainingStatsCubit>();
    final now = DateTime.now();
    final picked = await pickStatsDateRange(
      context,
      initial: state.customRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) cubit.selectCustomRange(picked);
  }

  List<Widget> _sections(
    BuildContext context,
    TrainingStatsSnapshot snapshot,
    TrainingStatsCubit cubit,
  ) {
    final empty = snapshot.isEmpty;
    final goal = snapshot.goal;
    final sections = <(String, Widget)>[
      ('kpi', StatsKpiGrid(snapshot: snapshot)),
      if (snapshot.insights.isNotEmpty)
        ('insights', StatsInsightsCard(insights: snapshot.insights)),
      if (goal != null) ('goal', StatsGoalCard(goal: goal)),
      if (empty)
        (
          'empty-range',
          StatsEmptyRangeNotice(
            onShowAll: snapshot.range == StatsRange.all
                ? null
                : () => cubit.selectRange(StatsRange.all),
          ),
        )
      else
        ('trend', StatsTrendChartCard(snapshot: snapshot)),
      // Rekordy, regeneracja i heatmapa liczą się z całej historii, więc mają
      // sens także przy pustym zakresie.
      (
        'records',
        StatsRecordsCard(
          records: snapshot.records,
          bests: snapshot.bests,
          now: snapshot.activity.today,
        ),
      ),
      if (!snapshot.sessionRecords.isEmpty)
        (
          'session-records',
          StatsSessionRecordsCard(records: snapshot.sessionRecords),
        ),
      if (!empty) ('muscles', StatsMusclesCard(muscles: snapshot.muscles)),
      if (snapshot.recovery.isNotEmpty)
        ('recovery', StatsRecoveryCard(recovery: snapshot.recovery)),
      if (!empty) ...[
        (
          'progress',
          StatsExerciseProgressCard(
            exercises: snapshot.exercises,
            progressFrom: snapshot.progressFrom,
          ),
        ),
        ('top-exercises', StatsTopExercisesCard(exercises: snapshot.exercises)),
        ('rep-ranges', StatsRepRangesCard(ranges: snapshot.repRanges)),
      ],
      ('activity', StatsActivityCard(activity: snapshot.activity)),
      if (!empty) ('habits', StatsHabitsCard(habits: snapshot.habits)),
    ];

    return [
      for (var i = 0; i < sections.length; i++)
        // Klucz trzyma stan karty (wybrana miara, ćwiczenie, zaznaczony dzień),
        // gdy przy zmianie zakresu sekcje nad nią pojawiają się i znikają.
        Padding(
          key: ValueKey('stats-${sections[i].$1}'),
          padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.md),
          child: StaggeredReveal(
            // Pierwsze karty wchodzą kaskadą, dalsze (poza ekranem) razem —
            // inaczej czekałyby na swoją kolej zbyt długo.
            index: i.clamp(0, 4),
            child: sections[i].$2,
          ),
        ),
    ];
  }
}
