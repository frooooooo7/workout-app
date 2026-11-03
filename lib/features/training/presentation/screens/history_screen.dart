import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../bloc/training_stats_cubit.dart';
import '../bloc/weekly_goal_source.dart';
import '../bloc/history_feed_cubit.dart';
import '../widgets/stats/stats_tab_bar.dart';
import '../widgets/stats/training_stats_view.dart';
import '../widgets/workout_history/history_calendar_sheet.dart';
import '../widgets/workout_history/history_segment_switch.dart';
import '../widgets/workout_history/history_sessions_panel.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Sesje i rekordy z lokalnej bazy: licznik celu, seria tygodni i lista
        // Historii biorą je stąd, a Statystyki z tych samych danych liczą swoje.
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
        // Lista treningów z ćwiczeniami — działa offline.
        BlocProvider(
          create: (context) => HistoryFeedCubit(
            context.read<TrainingStatsCubit>(),
            ServiceLocator.trainingHistoryRepository,
          ),
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

  /// Zakładka statystyk przeżywa przejście na listę sesji i z powrotem.
  StatsTab _statsTab = StatsTab.overview;

  final _panelKey = GlobalKey<HistorySessionsPanelState>();

  void _selectSegment(HistorySegment segment) {
    if (segment == _segment) return;
    setState(() => _segment = segment);
  }

  /// Przeciągnięcie listy: pełna synchronizacja (treningi z innych urządzeń),
  /// potem lista czyta lokalną bazę od nowa. Brak sieci nie blokuje odświeżenia.
  Future<void> _onRefresh(BuildContext context) async {
    HapticFeedback.lightImpact();
    final feed = context.read<HistoryFeedCubit>();
    try {
      await ServiceLocator.requestSync().timeout(const Duration(seconds: 8));
    } on Object {
      // Offline albo wolny serwer — pokazujemy to, co jest na telefonie.
    }
    await feed.load();
  }

  void _openCalendar(BuildContext context) {
    final entries = context.read<HistoryFeedCubit>().state.entries;
    final streak =
        context.read<TrainingStatsCubit>().state.snapshot?.currentStreakWeeks ??
        0;
    showHistoryCalendarSheet(
      context,
      entries: entries,
      streakWeeks: streak,
      onShowOnList: (day) => _panelKey.currentState?.showDay(day),
    );
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
              // 1. Nagłówek — tytuł, kalendarz (tylko przy sesjach) i wskaźnik
              //    synchronizacji.
              AppTabHeader(
                title: 'Historia',
                actions: [
                  if (!showStats)
                    AppTabHeaderButton(
                      icon: Icons.calendar_month_outlined,
                      tooltip: 'Kalendarz',
                      onPressed: () => _openCalendar(context),
                    ),
                ],
              ),

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
                Expanded(
                  child: TrainingStatsView(
                    onStartWorkout: () => context.go('/app/training'),
                    bodyWeightRepository: ServiceLocator.bodyWeightRepository,
                    initialTab: _statsTab,
                    onTabChanged: (tab) => _statsTab = tab,
                  ),
                ),
              ] else
                Expanded(
                  child: HistorySessionsPanel(
                    key: _panelKey,
                    onRefresh: () => _onRefresh(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
