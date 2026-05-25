import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../domain/models/custom_training_plan.dart';
import '../../domain/models/training_history_models.dart';
import '../../domain/models/training_session.dart';
import '../bloc/training_history_cubit.dart';
import '../bloc/training_plans_cubit.dart';
import '../bloc/training_session_cubit.dart';
import '../screens/create_plan_screen.dart';
import '../screens/ongoing_workout_screen.dart';
import '../screens/plan_details_screen.dart';
import 'training_active_session_card.dart';
import 'training_recent_progress_section.dart';
import 'training_today_plan_section.dart';

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
    return BlocProvider(
      create: (_) =>
          TrainingHistoryCubit(ServiceLocator.trainingHistoryRepository),
      child: BlocBuilder<TrainingPlansCubit, TrainingPlansState>(
        builder: (context, plansState) {
          return BlocBuilder<TrainingSessionCubit, TrainingSessionState>(
            builder: (context, sessionState) {
              return _TrainingSessionBody(
                selectedDay: _selectedDay,
                plansState: plansState,
                activeSession: sessionState.activeSession,
                onDaySelected: (day) => setState(() => _selectedDay = day),
                onResumeSession: (session) => _resumeSession(context, session),
                onOpenPlan: (plan) => _openPlan(context, plan),
                onStartPlan: (plan) => _startPlan(context, plan),
                onCreatePlanForDay: (day) => _createPlan(context, day),
                onOpenHistoryItem: (item) => context.push(
                  '/app/training/history/${item.id}',
                ),
              );
            },
          );
        },
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
      if (context.mounted) cubit.refresh();
    });
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
    final messenger = ScaffoldMessenger.of(context);
    final sessionCubit = context.read<TrainingSessionCubit>();
    final session = await sessionCubit.startFromPlan(plan);
    if (!context.mounted) return;
    if (session == null) {
      final conflict = sessionCubit.state.activeConflict;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Masz juz aktywna sesje. Wznow ja albo zakoncz przed startem nowej.',
          ),
        ),
      );
      if (conflict != null) {
        context.push(
          '/app/training/ongoing-workout',
          extra: OngoingWorkoutArgs(
            initialSession: conflict,
            sessionCubit: sessionCubit,
          ),
        );
      }
      return;
    }
    context.push(
      '/app/training/ongoing-workout',
      extra: OngoingWorkoutArgs(
        initialSession: session,
        sessionCubit: sessionCubit,
      ),
    );
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
    required this.activeSession,
    required this.onDaySelected,
    required this.onResumeSession,
    required this.onOpenPlan,
    required this.onStartPlan,
    required this.onCreatePlanForDay,
    required this.onOpenHistoryItem,
  });

  final int selectedDay;
  final TrainingPlansState plansState;
  final TrainingSession? activeSession;
  final ValueChanged<int> onDaySelected;
  final ValueChanged<TrainingSession> onResumeSession;
  final ValueChanged<CustomTrainingPlan> onOpenPlan;
  final Future<void> Function(CustomTrainingPlan plan) onStartPlan;
  final ValueChanged<int> onCreatePlanForDay;
  final ValueChanged<TrainingSessionListItem> onOpenHistoryItem;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (activeSession != null) ...[
            TrainingActiveSessionCard(
              planName: activeSession!.planName,
              onResume: () => onResumeSession(activeSession!),
            ),
            const SizedBox(height: 18),
          ],
          TrainingTodayPlanSection(
            selectedDay: selectedDay,
            plans: plansState.plans,
            isLoading: plansState.isLoading,
            onDaySelected: onDaySelected,
            onOpenPlan: onOpenPlan,
            onStartPlan: onStartPlan,
            onCreatePlanForDay: onCreatePlanForDay,
          ),
          const SizedBox(height: 24),
          BlocBuilder<TrainingHistoryCubit, TrainingHistoryState>(
            builder: (context, historyState) {
              return TrainingRecentProgressSection(
                state: historyState,
                onOpenSession: onOpenHistoryItem,
              );
            },
          ),
        ],
      ),
    );
  }
}
