import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/launch/app_launch_controller.dart';
import '../../../../core/launch/launch_ready_signal.dart';
import '../../../../core/services/service_locator.dart';
import '../../domain/models/custom_training_plan.dart';
import '../../domain/models/training_history_models.dart';
import '../../domain/models/training_home_insights.dart';
import '../../domain/models/training_session.dart';
import '../../domain/models/warmup.dart';
import '../bloc/training_history_cubit.dart';
import '../bloc/training_home_cubit.dart';
import '../bloc/training_plans_cubit.dart';
import '../bloc/training_session_cubit.dart';
import '../screens/create_plan_screen.dart';
import '../screens/ongoing_workout_screen.dart';
import '../screens/plan_details_screen.dart';
import '../utils/start_workout.dart';
import '../utils/warmup_gate.dart';
import 'training_active_warmup_card.dart';
import 'training_active_session_card.dart';
import 'training_last_session_section.dart';
import 'training_staggered_entrance.dart';
import 'training_today_plan_section.dart';
import 'training_week_strip.dart';

/// Zakładka startowa „Trening”: tydzień, plan wybranego dnia (domyślnie
/// dziś) i ostatni trening.
class TrainingSessionTab extends StatefulWidget {
  const TrainingSessionTab({super.key});

  @override
  State<TrainingSessionTab> createState() => _TrainingSessionTabState();
}

class _TrainingSessionTabState extends State<TrainingSessionTab> {
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now().weekday;
  }

  @override
  Widget build(BuildContext context) {
    final plansState = context.watch<TrainingPlansCubit>().state;
    final sessionState = context.watch<TrainingSessionCubit>().state;
    final historyState = context.watch<TrainingHistoryCubit>().state;
    final insights = context.watch<TrainingHomeCubit>().state;

    // Ekran startu czeka, aż wszystkie źródła skończą pierwsze wczytanie
    // (lokalna baza), żeby Trening pokazał się od razu z danymi.
    final firstLoadDone =
        !plansState.isLoading &&
        !sessionState.isLoading &&
        !historyState.loading &&
        insights.loaded;

    return LaunchReadySignal(
      target: LaunchTarget.training,
      ready: firstLoadDone,
      child: ValueListenableBuilder<WarmupInProgress?>(
        valueListenable: ServiceLocator.warmupSession.notifier,
        builder: (context, _, _) => _TrainingSessionBody(
          selectedDay: _selectedDay,
          plansState: plansState,
          historyState: historyState,
          insights: insights,
          activeSession: sessionState.activeSession,
          // Trening trwa, więc rozgrzewka (o ile jest) już nie jest potrzebna.
          warmup: sessionState.activeSession == null
              ? ServiceLocator.warmupSession.active
              : null,
          onDaySelected: (day) => setState(() => _selectedDay = day),
          onResumeSession: (session) => _resumeSession(context, session),
          onResumeWarmup: (warmup) =>
              _resumeWarmup(context, warmup, plansState.plans),
          onOpenPlan: (plan) => _openPlan(context, plan),
          onStartPlan: (plan) => _startPlan(context, plan),
          onStartCustom: () => _startCustom(context),
          onCreatePlanForDay: (day) => _createPlan(context, day),
          onOpenHistoryItem: (item) =>
              context.push('/app/training/history/${item.id}'),
        ),
      ),
    );
  }

  void _resumeSession(BuildContext context, TrainingSession session) {
    final cubit = context.read<TrainingSessionCubit>();
    context
        .push(
          '/app/training/ongoing-workout',
          extra: OngoingWorkoutArgs(
            initialSession: session,
            sessionCubit: cubit,
          ),
        )
        .then((_) {
          if (context.mounted) {
            cubit.refresh();
            context.read<TrainingHistoryCubit>().refresh();
            context.read<TrainingHomeCubit>().refresh();
          }
        });
  }

  /// Wraca do schowanej rozgrzewki: ten sam start co przy pierwszym stuknięciu,
  /// bramka otworzy trwający panel zamiast zaczynać od nowa.
  Future<void> _resumeWarmup(
    BuildContext context,
    WarmupInProgress warmup,
    List<CustomTrainingPlan> plans,
  ) async {
    // Rozgrzewkę kasujemy tylko wtedy, gdy WIEMY, że celu nie ma. Gdy lista
    // planów się jeszcze ładuje albo odczyt się nie udał, zostaje nietknięta.
    var gone = false;
    try {
      switch (warmup.target.kind) {
        case WarmupTargetKind.custom:
          await _startCustom(context);
          return;
        case WarmupTargetKind.plan:
          final planId = warmup.target.refId;
          final found = await findWarmupPlan(
            planId,
            plans,
            ServiceLocator.trainingPlanRepository,
          );
          if (!context.mounted) return;
          if (found != null) {
            await _startPlan(context, found);
            return;
          }
          gone = true;
        case WarmupTargetKind.repeat:
          final sessionId = warmup.target.refId;
          final source = sessionId == null
              ? null
              : await ServiceLocator.trainingSessionRepository.loadForEdit(
                  sessionId,
                );
          if (!context.mounted) return;
          if (source != null && source.exercises.isNotEmpty) {
            await startWorkout(
              context,
              start: (cubit) => cubit.startFromSession(source),
              warmup: WarmupRequest(target: warmup.target),
            );
            return;
          }
          gone = true;
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nie udało się teraz otworzyć treningu. Rozgrzewka trwa dalej, '
            'spróbuj za chwilę.',
          ),
        ),
      );
      return;
    }
    if (!gone) return;
    // Plan albo trening na pewno nie istnieje, więc rozgrzewka nie ma celu.
    await ServiceLocator.warmupSession.clear();
    await ServiceLocator.warmupGoalScheduler.cancelGoalReached().catchError(
      (_) {},
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ten trening już nie istnieje, więc kończę rozgrzewkę.'),
      ),
    );
  }

  void _openPlan(BuildContext context, CustomTrainingPlan plan) {
    context.push(
      '/app/training/plan-details',
      extra: PlanDetailsArgs(
        plan: plan,
        cubit: context.read<TrainingPlansCubit>(),
        sessionCubit: context.read<TrainingSessionCubit>(),
      ),
    );
  }

  Future<void> _startPlan(BuildContext context, CustomTrainingPlan plan) async {
    final historyCubit = context.read<TrainingHistoryCubit>();
    final homeCubit = context.read<TrainingHomeCubit>();
    final opened = await startPlanWorkout(context, plan);
    if (!opened) return;
    historyCubit.refresh();
    homeCubit.refresh();
  }

  /// Wolny trening — od razu pusta sesja, ćwiczenia dodaje się w trakcie.
  /// Wyjście bez ćwiczeń anuluje sesję.
  Future<void> _startCustom(BuildContext context) async {
    final historyCubit = context.read<TrainingHistoryCubit>();
    final homeCubit = context.read<TrainingHomeCubit>();
    final sessionCubit = context.read<TrainingSessionCubit>();
    final opened = await startWorkout(
      context,
      start: (cubit) => cubit.startCustom(),
      warmup: const WarmupRequest.custom(),
    );
    if (!opened) return;
    // Przypadkowe dotknięcie nie zostawia pustej „trwającej” sesji.
    await discardEmptyCustomSession(sessionCubit);
    historyCubit.refresh();
    homeCubit.refresh();
  }

  void _createPlan(BuildContext context, int day) {
    context.push(
      '/app/training/create-plan',
      extra: CreatePlanArgs(
        cubit: context.read<TrainingPlansCubit>(),
        initialSelectedDays: [day],
      ),
    );
  }
}

class _TrainingSessionBody extends StatelessWidget {
  const _TrainingSessionBody({
    required this.selectedDay,
    required this.plansState,
    required this.historyState,
    required this.insights,
    required this.activeSession,
    required this.warmup,
    required this.onDaySelected,
    required this.onResumeSession,
    required this.onResumeWarmup,
    required this.onOpenPlan,
    required this.onStartPlan,
    required this.onStartCustom,
    required this.onCreatePlanForDay,
    required this.onOpenHistoryItem,
  });

  final int selectedDay;
  final TrainingPlansState plansState;
  final TrainingHistoryState historyState;
  final TrainingHomeInsights insights;
  final TrainingSession? activeSession;

  /// Trwająca, ale schowana rozgrzewka przed treningiem.
  final WarmupInProgress? warmup;
  final ValueChanged<int> onDaySelected;
  final ValueChanged<TrainingSession> onResumeSession;
  final ValueChanged<WarmupInProgress> onResumeWarmup;
  final ValueChanged<CustomTrainingPlan> onOpenPlan;
  final Future<void> Function(CustomTrainingPlan plan) onStartPlan;
  final VoidCallback onStartCustom;
  final ValueChanged<int> onCreatePlanForDay;
  final ValueChanged<TrainingSessionListItem> onOpenHistoryItem;

  @override
  Widget build(BuildContext context) {
    final active = activeSession;
    final warmingUp = warmup;
    final sections = <Widget>[
      if (active != null)
        TrainingActiveSessionCard(
          planName: active.planName,
          onResume: () => onResumeSession(active),
        )
      else if (warmingUp != null)
        TrainingActiveWarmupCard(
          warmup: warmingUp,
          onResume: () => onResumeWarmup(warmingUp),
        ),
      TrainingWeekStrip(
        selectedDay: selectedDay,
        onDaySelected: onDaySelected,
        scheduledPlans: _scheduledPlans(plansState.plans),
        donePlans: insights.weekDonePlans,
        weeklyGoal: insights.weeklyGoal,
      ),
      TrainingTodayPlanSection(
        selectedDay: selectedDay,
        plans: plansState.plans,
        isLoading: plansState.isLoading,
        insights: insights,
        onOpenPlan: onOpenPlan,
        onStartPlan: onStartPlan,
        onStartCustom: onStartCustom,
        onCreatePlanForDay: onCreatePlanForDay,
        sessionInProgress: active != null || warmingUp != null,
        warmupInProgress: active == null && warmingUp != null,
      ),
      TrainingLastSessionSection(
        state: historyState,
        recordsBySession: insights.recordsBySession,
        onOpenDetails: onOpenHistoryItem,
      ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            TrainingStaggeredEntrance(
              key: ValueKey(sections[i].runtimeType),
              index: i,
              child: sections[i],
            ),
          ],
        ],
      ),
    );
  }

  /// Dzień tygodnia → pierwszy plan na ten dzień.
  static Map<int, String> _scheduledPlans(List<CustomTrainingPlan> plans) {
    final byDay = <int, String>{};
    for (final plan in plans) {
      for (final day in plan.selectedDays) {
        byDay.putIfAbsent(day, () => plan.name);
      }
    }
    return byDay;
  }
}
