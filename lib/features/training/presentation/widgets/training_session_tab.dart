import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/custom_training_plan.dart';
import '../bloc/training_history_cubit.dart';
import '../bloc/training_plans_cubit.dart';
import '../bloc/training_session_cubit.dart';
import '../screens/create_plan_screen.dart';
import '../screens/ongoing_workout_screen.dart';
import '../screens/plan_details_screen.dart';
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
              final active = sessionState.activeSession;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (active != null) ...[
                      _ActiveSessionCard(
                        planName: active.planName,
                        onResume: () {
                          final cubit = context.read<TrainingSessionCubit>();
                          context
                              .push(
                                '/app/training/ongoing-workout',
                                extra: OngoingWorkoutArgs(
                                  initialSession: active,
                                  sessionCubit: cubit,
                                ),
                              )
                              .then((_) {
                            if (context.mounted) cubit.refresh();
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                    ],
                    TrainingTodayPlanSection(
                      selectedDay: _selectedDay,
                      plans: plansState.plans,
                      isLoading: plansState.isLoading,
                      onDaySelected: (day) =>
                          setState(() => _selectedDay = day),
                      onOpenPlan: (plan) => _openPlan(context, plan),
                      onStartPlan: (plan) => _startPlan(context, plan),
                      onCreatePlanForDay: (day) => _createPlan(context, day),
                    ),
                    const SizedBox(height: 24),
                    BlocBuilder<TrainingHistoryCubit, TrainingHistoryState>(
                      builder: (context, historyState) {
                        return TrainingRecentProgressSection(
                          state: historyState,
                          onOpenSession: (item) => context.push(
                            '/app/training/history/${item.id}',
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
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

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({required this.planName, required this.onResume});

  final String planName;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aktywna sesja',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  planName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onResume, child: const Text('Wznow')),
        ],
      ),
    );
  }
}
