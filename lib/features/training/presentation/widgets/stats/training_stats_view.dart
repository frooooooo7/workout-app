import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_tab_header.dart';
import '../../../../profile/domain/repositories/body_weight_repository.dart';
import '../../../domain/models/training_stats.dart';
import '../../bloc/training_stats_cubit.dart';
import '../workout_summary/staggered_reveal.dart';
import 'overview/stats_notes_card.dart';
import 'overview/stats_period_summary_card.dart';
import 'overview/stats_tiles.dart';
import 'stats_body_weight_card.dart';
import 'stats_date_range_picker.dart';
import 'stats_detail_screen.dart';
import 'stats_navigation.dart';
import 'stats_period_navigator.dart';
import 'stats_range_selector.dart';
import 'stats_scroll_page.dart';
import 'stats_states.dart';

/// Pulpit statystyk: zakres dat nad przewijaną listą sześciu kart. Każda
/// karta odpowiada na jedno pytanie zdaniem-wnioskiem i otwiera ekran
/// szczegółów. Wymaga [TrainingStatsCubit] w kontekście.
class TrainingStatsView extends StatelessWidget {
  const TrainingStatsView({
    super.key,
    this.onStartWorkout,
    this.bodyWeightRepository,
  });

  /// Przycisk w pustym stanie (brak historii).
  final VoidCallback? onStartWorkout;

  /// Źródło karty „Masa ciała”; bez niego karty nie ma.
  final BodyWeightRepository? bodyWeightRepository;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainingStatsCubit, TrainingStatsState>(
      builder: (context, state) {
        final cubit = context.read<TrainingStatsCubit>();
        final snapshot = state.snapshot;
        final hasHistory = snapshot?.hasHistory ?? true;

        final Widget body;
        if (snapshot == null && state.failed) {
          body = StatsScrollPage(
            onRefresh: cubit.load,
            children: [StatsErrorState(onRetry: cubit.load)],
          );
        } else if (snapshot == null) {
          body = StatsScrollPage(
            onRefresh: cubit.load,
            children: const [StatsSkeleton()],
          );
        } else if (!snapshot.hasHistory) {
          body = StatsScrollPage(
            onRefresh: cubit.load,
            children: [StatsEmptyState(onStartWorkout: onStartWorkout)],
          );
        } else {
          body = StatsScrollPage(
            onRefresh: cubit.load,
            children: _cards(context, snapshot, cubit),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasHistory)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  AppSpacing.xxs,
                  AppSpacing.pageGutter,
                  AppSpacing.sm,
                ),
                child: StatsRangeSelector(
                  selected: state.range,
                  customRange: state.customRange,
                  onChanged: cubit.selectRange,
                  onPickCustom: () => _pickCustomRange(context, state),
                ),
              ),
            if (snapshot != null && snapshot.hasHistory)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageGutter,
                ),
                child: StatsPeriodNavigator(
                  snapshot: snapshot,
                  onShift: cubit.shiftPeriod,
                ),
              ),
            // Tuż nad przewijaną treścią, pod przypiętym zakresem.
            const AppTabScrollEdge(),
            Expanded(child: body),
          ],
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

  /// Pulpit w stałej kolejności: podsumowanie okresu, najwyżej dwie uwagi,
  /// cztery kafle działów i masa ciała. Rekordy życiowe, passa i gotowość
  /// mięśni liczą się z całej historii, więc przy pustym okresie zostają.
  List<Widget> _cards(
    BuildContext context,
    TrainingStatsSnapshot s,
    TrainingStatsCubit cubit,
  ) {
    final empty = s.isEmpty;
    final repository = bodyWeightRepository;
    void open(StatsDetail d) => openStatsDetail(context, d);
    final notes = empty
        ? const <StatsNote>[]
        : buildStatsNotes(
            s,
            onOpen: (insight) => switch (insight.kind) {
              StatsInsightKind.plateau || StatsInsightKind.progress
                  when insight.exerciseId != null &&
                      canOpenStatsExercise(insight.exerciseId!) =>
                () => openStatsExercise(context, insight.exerciseId!),
              StatsInsightKind.plateau ||
              StatsInsightKind.progress => () => open(StatsDetail.strength),
              StatsInsightKind.neglected => () => open(StatsDetail.muscles),
              StatsInsightKind.volumeDown => () => open(StatsDetail.trend),
              _ => null,
            },
          );

    final sections = <(String, Widget)>[
      (
        'period',
        StatsPeriodSummaryCard(
          snapshot: s,
          onOpenTrend: () => open(StatsDetail.trend),
        ),
      ),
      if (empty)
        (
          'empty-range',
          StatsEmptyRangeNotice(
            onShowAll: s.range == StatsRange.all
                ? null
                : () => cubit.selectRange(StatsRange.all),
          ),
        ),
      if (notes.isNotEmpty) ('notes', StatsNotesCard(notes: notes)),
      ('tiles', StatsTilesGrid(snapshot: s, now: DateTime.now(), onOpen: open)),
      if (repository != null)
        (
          'body-weight',
          StatsBodyWeightCard(repository: repository, window: s.window),
        ),
    ];

    return [
      for (var i = 0; i < sections.length; i++)
        // Klucz trzyma stan karty, gdy przy zmianie zakresu sekcje nad nią
        // pojawiają się i znikają.
        Padding(
          key: ValueKey('stats-${sections[i].$1}'),
          padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.sm),
          child: StaggeredReveal(
            // Pierwsze karty wchodzą kaskadą, dalsze (poza ekranem) razem —
            // inaczej czekałyby na swoją kolej zbyt długo.
            index: i.clamp(0, 4),
            child: sections[i].$2,
          ),
        ),
      const Padding(
        padding: EdgeInsets.fromLTRB(8, AppSpacing.md, 8, 0),
        child: Text(
          'Rekordy życiowe, passa i gotowość mięśni liczą się '
          'z całej historii, niezależnie od okresu.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
      ),
    ];
  }
}
