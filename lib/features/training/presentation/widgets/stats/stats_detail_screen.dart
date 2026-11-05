import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_tab_header.dart';
import '../../../domain/models/training_stats.dart';
import '../../bloc/training_stats_cubit.dart';
import '../workout_summary/staggered_reveal.dart';
import 'stats_exercise_progress_card.dart';
import 'stats_goal_card.dart';
import 'stats_habits_card.dart';
import 'stats_muscles_card.dart';
import 'stats_range_sheet.dart';
import 'stats_records_card.dart';
import 'stats_recovery_card.dart';
import 'stats_rep_ranges_card.dart';
import 'stats_scroll_page.dart';
import 'stats_session_records_card.dart';
import 'stats_states.dart';
import 'stats_top_exercises_card.dart';
import 'stats_trend_chart_card.dart';

/// Ekrany szczegółów otwierane z kart pulpitu.
enum StatsDetail {
  trend('Przebieg'),
  strength('Siła'),
  records('Rekordy'),
  muscles('Mięśnie'),
  consistency('Regularność');

  const StatsDetail(this.title);

  final String title;
}

/// Otwiera ekran szczegółów na tym samym [TrainingStatsCubit], więc zakres
/// dat i dane są wspólne z pulpitem.
Future<void> openStatsDetail(BuildContext context, StatsDetail detail) {
  final cubit = context.read<TrainingStatsCubit>();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: RouteSettings(name: 'stats-${detail.name}'),
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: StatsDetailScreen(detail: detail),
      ),
    ),
  );
}

/// Wspólny szkielet: wstecz, tytuł, zakres „30 dni ▾” i przewijana lista kart.
class StatsDetailScreen extends StatelessWidget {
  const StatsDetailScreen({super.key, required this.detail});

  final StatsDetail detail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppTabBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTabHeader(
                title: detail.title,
                showSync: false,
                leading: AppTabHeaderButton.back(
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                actions: const [StatsRangeChip()],
              ),
              const SizedBox(height: AppSpacing.xxs),
              const AppTabScrollEdge(),
              Expanded(child: _Body(detail: detail)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.detail});

  final StatsDetail detail;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainingStatsCubit, TrainingStatsState>(
      builder: (context, state) {
        final cubit = context.read<TrainingStatsCubit>();
        final snapshot = state.snapshot;
        if (snapshot == null) {
          return StatsScrollPage(
            onRefresh: cubit.load,
            children: [
              if (state.failed)
                StatsErrorState(onRetry: cubit.load)
              else
                const StatsSkeleton(),
            ],
          );
        }
        final cards = _cards(detail, snapshot, cubit);
        return StatsScrollPage(
          onRefresh: cubit.load,
          children: [
            for (var i = 0; i < cards.length; i++)
              Padding(
                key: ValueKey('stats-${detail.name}-${cards[i].$1}'),
                padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.md),
                child: StaggeredReveal(
                  index: i.clamp(0, 4),
                  child: cards[i].$2,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Karty ekranu. Rekordy, regeneracja i passa liczą się z całej historii,
  /// więc mają sens także przy pustym zakresie; reszta czeka na dane.
  List<(String, Widget)> _cards(
    StatsDetail detail,
    TrainingStatsSnapshot s,
    TrainingStatsCubit cubit,
  ) {
    final empty = s.isEmpty;
    final goal = s.goal;
    final cards = <(String, Widget)>[
      ...switch (detail) {
        StatsDetail.trend => [
          if (!empty) ('trend', StatsTrendChartCard(snapshot: s)),
        ],
        StatsDetail.strength => [
          if (!empty) ...[
            (
              'progress',
              StatsExerciseProgressCard(
                exercises: s.exercises,
                progressFrom: s.progressFrom,
              ),
            ),
            ('all-exercises', StatsAllExercisesCard(exercises: s.exercises)),
            ('rep-ranges', StatsRepRangesCard(ranges: s.repRanges)),
          ],
        ],
        StatsDetail.records => [
          (
            'records',
            StatsRecordsCard(
              records: s.records,
              bests: s.bests,
              now: s.activity.today,
            ),
          ),
          if (!s.sessionRecords.isEmpty)
            (
              'session-records',
              StatsSessionRecordsCard(records: s.sessionRecords),
            ),
        ],
        StatsDetail.muscles => [
          if (!empty) ...[
            ('map', StatsMuscleMapCard(muscles: s.muscles)),
            (
              'region-bars',
              StatsRegionBarsCard(
                muscles: s.muscles,
                window: s.window,
                rangeLabel: _rangeLabel(s),
              ),
            ),
            ('ranking', StatsMuscleRankingCard(muscles: s.muscles)),
          ],
          if (s.recovery.isNotEmpty)
            ('recovery', StatsRecoveryCard(recovery: s.recovery)),
        ],
        StatsDetail.consistency => [
          if (goal != null)
            ('goal', StatsGoalCard(goal: goal))
          else
            (
              'streak',
              StatsStreakCard(
                streakWeeks: s.currentStreakWeeks,
                bestStreakWeeks: s.bestStreakWeeks,
              ),
            ),
          if (!empty) ('habits', StatsHabitsCard(habits: s.habits)),
        ],
      },
    ];
    if (empty) {
      // Pusty zakres: karty z całej historii zostają, a pod nimi (albo sama,
      // gdy ich nie ma) notatka z podpowiedzią.
      cards.add((
        'empty-range',
        StatsEmptyRangeNotice(
          onShowAll: s.range == StatsRange.all
              ? null
              : () => cubit.selectRange(StatsRange.all),
        ),
      ));
    }
    return cards;
  }

  static String _rangeLabel(TrainingStatsSnapshot s) =>
      s.range == StatsRange.custom ? 'wybranego okresu' : s.range.label;
}
