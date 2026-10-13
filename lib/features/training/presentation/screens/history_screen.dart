import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../../core/widgets/skeleton.dart';
import '../bloc/training_stats_cubit.dart';
import '../bloc/weekly_goal_source.dart';
import '../bloc/workout_history_cubit.dart';
import '../widgets/stats/training_stats_view.dart';
import '../widgets/workout_history/history_month_calendar.dart';
import '../widgets/workout_history/history_month_navigator.dart';
import '../widgets/workout_history/history_segment_switch.dart';
import '../widgets/workout_history/history_week_sessions_list.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => WorkoutHistoryCubit(
            ServiceLocator.trainingHistoryRepository,
            dataChanges: ServiceLocator.trainingSessionDataChanges,
          ),
        ),
        // Liczone od razu: lista sesji bierze z nich serię tygodni
        // i rekordy pobite w każdej sesji.
        BlocProvider(
          create: (_) => TrainingStatsCubit(
            ServiceLocator.trainingStatsRepository,
            // Wnioski to gotowy tekst z jednostką — po zmianie kg/lb liczymy je
            // od nowa.
            dataChanges: Listenable.merge([
              ServiceLocator.trainingSessionDataChanges,
              WeightUnits.notifier,
            ]),
            weeklyGoalLoader: loadOwnWeeklyGoal,
          )..load(),
        ),
      ],
      child: const _WorkoutHistoryView(),
    );
  }
}

class _WorkoutHistoryView extends StatefulWidget {
  const _WorkoutHistoryView();

  @override
  State<_WorkoutHistoryView> createState() => _WorkoutHistoryViewState();
}

class _WorkoutHistoryViewState extends State<_WorkoutHistoryView> {
  HistorySegment _segment = HistorySegment.sessions;

  void _selectSegment(HistorySegment segment) {
    if (segment == _segment) return;
    setState(() => _segment = segment);
  }

  Future<void> _onRefresh(BuildContext context) async {
    HapticFeedback.lightImpact();
    await context.read<WorkoutHistoryCubit>().refresh();
  }

  /// Miesiąc obok bieżącego ([step] = -1 poprzedni, 1 następny) albo `null`,
  /// gdy wychodzi poza dostępny zakres.
  DateTime? _adjacentMonth(WorkoutHistoryState state, int step) {
    final months = state.availableMonths;
    final index = months.indexWhere(
      (m) =>
          m.year == state.focusedMonth.year &&
          m.month == state.focusedMonth.month,
    );
    final target = index + step;
    if (index == -1 || target < 0 || target >= months.length) return null;
    return months[target];
  }

  void _onHorizontalDragEnd(
    BuildContext context,
    DragEndDetails details,
    WorkoutHistoryState state,
  ) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 200) return;
    // Przesunięcie w lewo — następny miesiąc, w prawo — poprzedni.
    final month = _adjacentMonth(state, velocity < 0 ? 1 : -1);
    if (month != null) context.read<WorkoutHistoryCubit>().selectMonth(month);
  }

  @override
  Widget build(BuildContext context) {
    final showStats = _segment == HistorySegment.stats;
    return Scaffold(
      backgroundColor: AppColors.background,
      // Bottom inset (incl. the shell's bottom nav) is left to the scroll view.
      body: AppTabBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Nagłówek — tytuł i wskaźnik synchronizacji.
              const AppTabHeader(title: 'Historia'),

              // 2. Podzakładki: sesje / statystyki
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  0,
                ),
                child: HistorySegmentSwitch(
                  selected: _segment,
                  onChanged: _selectSegment,
                ),
              ),

              if (showStats) ...[
                const SizedBox(height: AppSpacing.sm),
                const AppTabScrollEdge(),
                Expanded(
                  child: TrainingStatsView(
                    onStartWorkout: () => context.go('/app/training'),
                    bodyWeightRepository: ServiceLocator.bodyWeightRepository,
                  ),
                ),
              ] else
                Expanded(child: _buildSessions(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessions(BuildContext context) {
    return BlocBuilder<WorkoutHistoryCubit, WorkoutHistoryState>(
      builder: (context, state) {
        final cubit = context.read<WorkoutHistoryCubit>();
        final previous = _adjacentMonth(state, -1);
        final next = _adjacentMonth(state, 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 3. Miesiąc: strzałki, nazwa i podsumowanie w jednej linii.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: HistoryMonthNavigator(
                month: state.focusedMonth,
                stats: state.monthlyHistory?.stats,
                onPrevious: previous == null
                    ? null
                    : () => cubit.selectMonth(previous),
                onNext: next == null ? null : () => cubit.selectMonth(next),
                onPickMonth: () => cubit.openMonthPicker(context),
              ),
            ),
            const AppTabScrollEdge(),

            // 4. Kalendarz i sesje — przesunięcie w bok zmienia miesiąc.
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) =>
                    _onHorizontalDragEnd(context, details, state),
                behavior: HitTestBehavior.opaque,
                child: RefreshIndicator(
                  onRefresh: () => _onRefresh(context),
                  color: AppColors.primary,
                  child: _buildBody(context, state, cubit),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    WorkoutHistoryState state,
    WorkoutHistoryCubit cubit,
  ) {
    if (state.isLoading) {
      return const _WorkoutHistorySkeleton();
    }

    if (state.error != null && state.monthlyHistory == null) {
      return _WorkoutHistoryError(
        message: state.error!,
        onRetry: () => cubit.refresh(),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessions = state.monthlyHistory?.sessions ?? const [];
    final stats = context.select(
      (TrainingStatsCubit c) => (
        streak: c.state.snapshot?.currentStreakWeeks ?? 0,
        records: c.state.recordsBySession,
      ),
    );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.fromCache)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'Tryb offline: pokazujemy zapisane dane z pamięci podręcznej.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: state.isMonthChanging
                      ? const Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                HistoryMonthCalendar(
                  month: state.focusedMonth,
                  sessions: sessions,
                  today: today,
                  selectedDay: state.selectedDay,
                  streakWeeks: stats.streak,
                  onDayTap: cubit.toggleDaySelection,
                ),
              ],
            ),
          ),
        ),
        HistoryWeekSessionsList(
          sessions: state.filteredSessions,
          today: today,
          selectedDay: state.selectedDay,
          recordsBySession: stats.records,
          onClearDay: cubit.clearDaySelection,
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}

/// Szkielet pierwszego wczytania: kalendarz i kilka wierszy sesji.
class _WorkoutHistorySkeleton extends StatelessWidget {
  const _WorkoutHistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      label: 'Wczytywanie historii',
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xs + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const SkeletonBlock(height: 300, radius: 22),
          const SizedBox(height: AppSpacing.md),
          const SkeletonBlock(width: 180, height: 16),
          for (var i = 0; i < 3; i++) ...[
            const SizedBox(height: AppSpacing.xs),
            const SkeletonBlock(height: 64, radius: 18),
          ],
        ],
      ),
    );
  }
}

class _WorkoutHistoryError extends StatelessWidget {
  const _WorkoutHistoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.textMuted,
              size: 36,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }
}
