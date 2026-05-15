import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/custom_training_plan.dart';
import '../bloc/training_plans_cubit.dart';
import '../bloc/training_session_cubit.dart';
import '../screens/plan_details_screen.dart';

class TrainingPlansTab extends StatelessWidget {
  const TrainingPlansTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainingPlansCubit, TrainingPlansState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PlansDashboardHeader(plans: state.plans),
                  const SizedBox(height: 18),
                  if (state.plans.isEmpty)
                    const _EmptyState()
                  else
                    ...state.plans.map(
                      (plan) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _TrainingPlanTile(plan: plan),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlansDashboardHeader extends StatelessWidget {
  const _PlansDashboardHeader({required this.plans});

  final List<CustomTrainingPlan> plans;

  int get _exerciseCount =>
      plans.fold(0, (sum, plan) => sum + plan.exercises.length);

  int get _trainingDays =>
      plans.expand((plan) => plan.selectedDays).toSet().length;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceVariant.withValues(alpha: 0.96),
            AppColors.surface,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.dashboard_customize_rounded,
                  color: AppColors.primaryVariant,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Twoje plany',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Centrum dowodzenia dla gotowych treningow.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _DashboardMetric(
                  value: '${plans.length}',
                  label: 'plany',
                ),
              ),
              const _MetricDivider(),
              Expanded(
                child: _DashboardMetric(
                  value: '$_exerciseCount',
                  label: 'cwiczen',
                ),
              ),
              const _MetricDivider(),
              Expanded(
                child: _DashboardMetric(value: '$_trainingDays', label: 'dni'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

class _TrainingPlanTile extends StatelessWidget {
  const _TrainingPlanTile({required this.plan});

  final CustomTrainingPlan plan;

  String get _exerciseLabel {
    final count = plan.exercises.length;
    if (count == 1) return '1 cwiczenie';
    return '$count cwiczen';
  }

  String get _setLabel {
    final count = plan.exercises.fold(
      0,
      (sum, exercise) => sum + exercise.sets.length,
    );
    if (count == 1) return '1 seria';
    return '$count serii';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push(
            '/app/training/plan-details',
            extra: PlanDetailsArgs(
              plan: plan,
              cubit: context.read<TrainingPlansCubit>(),
              sessionCubit: context.read<TrainingSessionCubit>(),
            ),
          );
        },
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      color: AppColors.primaryVariant,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _PlanInfoPill(
                              icon: Icons.format_list_bulleted_rounded,
                              label: _exerciseLabel,
                            ),
                            _PlanInfoPill(
                              icon: Icons.stacked_bar_chart_rounded,
                              label: _setLabel,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Usun plan',
                    onPressed: () {
                      context.read<TrainingPlansCubit>().removePlan(plan.id);
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFFF6B6B),
                    ),
                  ),
                ],
              ),
              if (plan.note != null && plan.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  plan.note!.trim(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.textMuted,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  _DaySchedule(selectedDays: plan.selectedDays),
                  const SizedBox(width: 10),
                  Text(
                    plan.selectedDays.isEmpty
                        ? 'bez harmonogramu'
                        : '${plan.selectedDays.length} dni treningowe',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Szczegoly planu',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Otworz',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primaryVariant,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanInfoPill extends StatelessWidget {
  const _PlanInfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySchedule extends StatelessWidget {
  const _DaySchedule({required this.selectedDays});

  final List<int> selectedDays;

  @override
  Widget build(BuildContext context) {
    final selected = selectedDays.toSet();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (index) {
        final day = index + 1;
        final isSelected = selected.contains(day);

        return Padding(
          padding: EdgeInsets.only(right: index == 6 ? 0 : 5),
          child: Container(
            key: ValueKey(
              'plan-day-dot-$day-${isSelected ? 'selected' : 'idle'}',
            ),
            width: isSelected ? 9 : 6,
            height: isSelected ? 9 : 6,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryVariant
                  : AppColors.textMuted.withValues(alpha: 0.45),
              shape: BoxShape.circle,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primaryVariant.withValues(alpha: 0.35),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.add_task_rounded,
              color: AppColors.primaryVariant,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Zbuduj pierwszy plan',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Zapisz cwiczenia, dni tygodnia i notatki, zeby start treningu byl jednym tapnieciem.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
