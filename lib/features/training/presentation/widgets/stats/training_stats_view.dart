import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_tab_header.dart';
import '../../../../profile/domain/repositories/body_weight_repository.dart';
import '../../../domain/models/training_stats.dart';
import '../../bloc/training_stats_cubit.dart';
import '../workout_summary/staggered_reveal.dart';
import 'stats_activity_card.dart';
import 'stats_body_weight_card.dart';
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
import 'stats_tab_bar.dart';
import 'stats_top_exercises_card.dart';
import 'stats_trend_chart_card.dart';

/// Treść statystyk: zakres dat, zakładki i karty z wykresami. Wymaga
/// [TrainingStatsCubit] w kontekście.
///
/// Zakres dat i zakładki stoją nad przewijaną treścią, a zakres obowiązuje
/// we wszystkich zakładkach. Każda zakładka ma własną pozycję przewinięcia,
/// a karty już odwiedzonych zakładek zostają w drzewie, więc po powrocie
/// trzymają wybrane ćwiczenie, miarę czy zaznaczony dzień.
class TrainingStatsView extends StatefulWidget {
  const TrainingStatsView({
    super.key,
    this.onStartWorkout,
    this.bodyWeightRepository,
    this.initialTab = StatsTab.overview,
    this.onTabChanged,
  });

  /// Przycisk w pustym stanie (brak historii).
  final VoidCallback? onStartWorkout;

  /// Źródło karty „Masa ciała”; bez niego karty nie ma.
  final BodyWeightRepository? bodyWeightRepository;

  /// Zakładka na starcie. Historia podaje tu ostatnio wybraną, bo widok jest
  /// niszczony przy przejściu na listę sesji.
  final StatsTab initialTab;

  /// Wołane po zmianie zakładki.
  final ValueChanged<StatsTab>? onTabChanged;

  @override
  State<TrainingStatsView> createState() => _TrainingStatsViewState();
}

class _TrainingStatsViewState extends State<TrainingStatsView> {
  late StatsTab _tab = widget.initialTab;

  /// Zakładki, które były już otwarte. Pozostałych nie budujemy z góry, dzięki
  /// czemu karty wchodzą animacją dopiero przy pierwszej wizycie.
  late final Set<StatsTab> _visited = {widget.initialTab};

  /// Osobny kontroler na zakładkę — po przełączeniu odczytujemy z niego
  /// pozycję przewinięcia nowej zakładki (patrz [_syncScrollChrome]).
  final _controllers = {
    for (final tab in StatsTab.values) tab: ScrollController(),
  };

  @override
  void initState() {
    super.initState();
    _syncScrollChrome();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _selectTab(StatsTab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
    widget.onTabChanged?.call(tab);
    _syncScrollChrome();
  }

  /// Poświata tła i linia krawędzi ([AppTabBackground], [AppTabScrollEdge])
  /// śledzą wyłącznie powiadomienia o przewijaniu, a przełączenie zakładki
  /// żadnego nie wysyła. Po klatce z nową zakładką wysyłamy więc zerowe
  /// przesunięcie, które niesie jej aktualny offset.
  void _syncScrollChrome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = _controllers[_tab]!;
      if (controller.hasClients) {
        controller.position.didUpdateScrollPositionBy(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainingStatsCubit, TrainingStatsState>(
      builder: (context, state) {
        final cubit = context.read<TrainingStatsCubit>();
        final snapshot = state.snapshot;

        final hasHistory = snapshot?.hasHistory ?? true;

        final Widget body;
        if (snapshot == null && state.failed) {
          body = _ScrollPage(
            onRefresh: cubit.load,
            children: [StatsErrorState(onRetry: cubit.load)],
          );
        } else if (snapshot == null) {
          body = _ScrollPage(
            onRefresh: cubit.load,
            children: const [StatsSkeleton()],
          );
        } else if (!snapshot.hasHistory) {
          body = _ScrollPage(
            onRefresh: cubit.load,
            children: [StatsEmptyState(onStartWorkout: widget.onStartWorkout)],
          );
        } else {
          body = Stack(
            fit: StackFit.expand,
            children: [
              for (final tab in StatsTab.values)
                if (_visited.contains(tab))
                  // Offstage + TickerMode: ukryta zakładka zachowuje stan
                  // i przewinięcie, ale nie jest malowana, nie przyjmuje
                  // dotyku i nie liczy animacji (układ nadal się liczy).
                  // Klucz: lista dzieci jest filtrowana przez `_visited`, więc
                  // bez niego zakładka odwiedzona „ze środka” przejęłaby
                  // element (a z nim przewinięcie) sąsiada.
                  Offstage(
                    key: ValueKey(tab),
                    offstage: tab != _tab,
                    child: TickerMode(
                      enabled: tab == _tab,
                      child: _ScrollPage(
                        controller: _controllers[tab],
                        onRefresh: cubit.load,
                        children: _cards(tab, snapshot, cubit),
                      ),
                    ),
                  ),
            ],
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StatsRangeSelector(
                      selected: state.range,
                      customRange: state.customRange,
                      onChanged: cubit.selectRange,
                      onPickCustom: () => _pickCustomRange(context, state),
                    ),
                    // Zakładki pojawiają się razem z danymi — na szkielecie
                    // czy błędzie nie ma czym przełączać.
                    if (snapshot != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      StatsTabBar(selected: _tab, onChanged: _selectTab),
                    ],
                  ],
                ),
              ),
            // Tuż nad przewijaną treścią, pod przypiętym zakresem i zakładkami.
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

  /// Karty jednej zakładki. Rekordy, regeneracja i heatmapa liczą się z całej
  /// historii, więc mają sens także przy pustym zakresie.
  List<Widget> _cards(
    StatsTab tab,
    TrainingStatsSnapshot snapshot,
    TrainingStatsCubit cubit,
  ) {
    final empty = snapshot.isEmpty;
    final goal = snapshot.goal;
    final repository = widget.bodyWeightRepository;
    final sections = <(String, Widget)>[
      ...switch (tab) {
        StatsTab.overview => [
          ('kpi', StatsKpiGrid(snapshot: snapshot)),
          if (snapshot.insights.isNotEmpty)
            ('insights', StatsInsightsCard(insights: snapshot.insights)),
          if (!empty) ('trend', StatsTrendChartCard(snapshot: snapshot)),
        ],
        StatsTab.progress => [
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
          if (!empty) ...[
            (
              'progress',
              StatsExerciseProgressCard(
                exercises: snapshot.exercises,
                progressFrom: snapshot.progressFrom,
              ),
            ),
            (
              'top-exercises',
              StatsTopExercisesCard(exercises: snapshot.exercises),
            ),
            ('rep-ranges', StatsRepRangesCard(ranges: snapshot.repRanges)),
          ],
        ],
        StatsTab.body => [
          if (!empty) ('muscles', StatsMusclesCard(muscles: snapshot.muscles)),
          if (snapshot.recovery.isNotEmpty)
            ('recovery', StatsRecoveryCard(recovery: snapshot.recovery)),
          if (repository != null)
            (
              'body-weight',
              StatsBodyWeightCard(
                repository: repository,
                window: snapshot.window,
              ),
            ),
        ],
        StatsTab.consistency => [
          if (goal != null) ('goal', StatsGoalCard(goal: goal)),
          ('activity', StatsActivityCard(activity: snapshot.activity)),
          if (!empty) ('habits', StatsHabitsCard(habits: snapshot.habits)),
        ],
      },
    ];

    // Pusty zakres bez kart rozliczanych z całej historii (np. „Ciało” bez
    // regeneracji i wagi) — zamiast pustej zakładki podpowiadamy cały okres.
    // Na „Przeglądzie” kafelki zostają, więc notatka idzie pod nimi.
    final notice = empty && (tab == StatsTab.overview || sections.isEmpty)
        ? (
            'empty-range',
            StatsEmptyRangeNotice(
              onShowAll: snapshot.range == StatsRange.all
                  ? null
                  : () => cubit.selectRange(StatsRange.all),
            ),
          )
        : null;
    if (notice != null) sections.add(notice);

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

/// Przewijana kolumna z odświeżaniem pociągnięciem.
///
/// Kolumna zamiast ListView: ListView niszczy karty poza ekranem, więc po
/// powrocie traciłyby stan (wybrane ćwiczenie, zaznaczony dzień) i animowały
/// się od nowa. Kart w zakładce jest kilka — budujemy wszystkie.
class _ScrollPage extends StatelessWidget {
  const _ScrollPage({
    this.controller,
    required this.onRefresh,
    required this.children,
  });

  final ScrollController? controller;
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () {
        HapticFeedback.lightImpact();
        return onRefresh();
      },
      child: SingleChildScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.pageGutter,
          AppSpacing.xxs,
          AppSpacing.pageGutter,
          AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
