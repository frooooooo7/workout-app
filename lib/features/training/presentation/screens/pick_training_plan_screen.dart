import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/custom_training_plan.dart';
import '../bloc/training_plans_cubit.dart';
import '../bloc/training_session_cubit.dart';
import 'ongoing_workout_screen.dart';

class PickTrainingPlanScreen extends StatelessWidget {
  const PickTrainingPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              TrainingPlansCubit(ServiceLocator.trainingPlanRepository),
        ),
        BlocProvider(
          create: (_) =>
              TrainingSessionCubit(ServiceLocator.trainingSessionRepository),
        ),
      ],
      child: const _PickTrainingPlanView(),
    );
  }
}

class _PickTrainingPlanView extends StatelessWidget {
  const _PickTrainingPlanView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Moje plany',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: BlocBuilder<TrainingPlansCubit, TrainingPlansState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (state.plans.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Nie masz jeszcze planow treningowych.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              itemCount: state.plans.length,
              itemBuilder: (context, index) {
                return _ExpandablePlanCard(plan: state.plans[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _ExpandablePlanCard extends StatefulWidget {
  const _ExpandablePlanCard({required this.plan});

  final CustomTrainingPlan plan;

  @override
  State<_ExpandablePlanCard> createState() => _ExpandablePlanCardState();
}

class _ExpandablePlanCardState extends State<_ExpandablePlanCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${plan.exercises.length} cwiczen',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...plan.exercises.map(
                    (exercise) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fitness_center_rounded,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              exercise.exercise.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${exercise.sets.length} serie',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _startPlan(context, plan),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Rozpocznij trening'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startPlan(BuildContext context, CustomTrainingPlan plan) async {
    final messenger = ScaffoldMessenger.of(context);
    final sessionCubit = context.read<TrainingSessionCubit>();
    final session = await sessionCubit.startFromPlan(plan);
    if (!context.mounted) return;
    final selected = session ?? sessionCubit.state.activeConflict;
    if (session == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Masz juz aktywna sesje. Wznawiam obecny trening.'),
        ),
      );
    }
    if (selected == null) return;
    context.pushReplacement(
      '/app/training/ongoing-workout',
      extra: OngoingWorkoutArgs(
        initialSession: selected,
        sessionCubit: sessionCubit,
      ),
    );
  }
}
