import 'dart:async';

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
import '../widgets/workout_history/history_calendar_sheet.dart';
import '../widgets/workout_history/history_stats_hint.dart';
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
  final _panelKey = GlobalKey<HistorySessionsPanelState>();

  /// Jednorazowy dymek przy ikonie statystyk (przeniosły się tu z zakładki).
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    unawaited(_maybeShowHint());
  }

  Future<void> _maybeShowHint() async {
    if (await historyStatsHintSeen()) return;
    if (!mounted) return;
    // Dymek jest dla osób, które znały zakładkę Statystyki — nowemu
    // użytkownikowi, bez żadnego treningu, nie ma co wskazywać.
    final stats = context.read<TrainingStatsCubit>();
    var state = stats.state;
    if (state.snapshot == null && !state.failed) {
      state = await stats.stream
          .firstWhere((s) => s.snapshot != null || s.failed)
          .timeout(const Duration(seconds: 10), onTimeout: () => stats.state);
    }
    if (!mounted || state.sessions.isEmpty) return;
    setState(() => _showHint = true);
    await markHistoryStatsHintSeen();
  }

  void _dismissHint() {
    if (_showHint && mounted) setState(() => _showHint = false);
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
    _dismissHint();
    final entries = context.read<HistoryFeedCubit>().state.entries;
    final streak =
        context.read<TrainingStatsCubit>().state.snapshot?.streakWeeks ?? 0;
    showHistoryCalendarSheet(
      context,
      entries: entries,
      streakWeeks: streak,
      onShowOnList: (day) => _panelKey.currentState?.showDay(day),
    );
  }

  void _openStats(BuildContext context) {
    _dismissHint();
    context.push(
      '/app/training/stats',
      extra: context.read<TrainingStatsCubit>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Bottom inset (incl. the shell's bottom nav) is left to the scroll view.
      body: AppTabBackground(
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Nagłówek — tytuł, statystyki, kalendarz i wskaźnik
                  // synchronizacji.
                  AppTabHeader(
                    title: 'Historia',
                    actions: [
                      AppTabHeaderButton(
                        icon: Icons.bar_chart_rounded,
                        tooltip: 'Statystyki',
                        onPressed: () => _openStats(context),
                      ),
                      AppTabHeaderButton(
                        icon: Icons.calendar_month_outlined,
                        tooltip: 'Kalendarz',
                        onPressed: () => _openCalendar(context),
                      ),
                    ],
                  ),
                  Expanded(
                    child: HistorySessionsPanel(
                      key: _panelKey,
                      onRefresh: () => _onRefresh(context),
                    ),
                  ),
                ],
              ),
              if (_showHint)
                Positioned(
                  top: AppSpacing.sm + AppTabHeader.height + AppSpacing.xxs,
                  right: AppSpacing.pageGutter,
                  child: HistoryStatsHint(onDismiss: _dismissHint),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
