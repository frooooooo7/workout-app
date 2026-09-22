import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/models/custom_training_plan.dart';
import '../bloc/training_plans_cubit.dart';
import '../bloc/training_session_cubit.dart';
import '../screens/create_plan_screen.dart';
import '../screens/plan_details_screen.dart';
import '../utils/start_workout.dart';
import 'plans/plan_card.dart';
import 'plans/plans_states.dart';
import 'plans/plans_week_card.dart';
import 'training_day_status.dart';

class TrainingPlansTab extends StatefulWidget {
  const TrainingPlansTab({super.key, this.now});

  /// Test seam dla „dzisiejszego” dnia tygodnia.
  final DateTime? now;

  @override
  State<TrainingPlansTab> createState() => _TrainingPlansTabState();
}

class _TrainingPlansTabState extends State<TrainingPlansTab> {
  static const _maxContentWidth = 620.0;

  /// Filtr listy po dniu tygodnia (1–7); `null` — wszystkie plany.
  int? _dayFilter;

  int get _today => (widget.now ?? DateTime.now()).weekday;

  void _toggleDay(int day) {
    setState(() => _dayFilter = _dayFilter == day ? null : day);
  }

  void _openPlan(CustomTrainingPlan plan) {
    context.push(
      '/app/training/plan-details',
      extra: PlanDetailsArgs(
        plan: plan,
        cubit: context.read<TrainingPlansCubit>(),
        sessionCubit: context.read<TrainingSessionCubit>(),
      ),
    );
  }

  void _createPlan({List<int> days = const []}) {
    context.push(
      '/app/training/create-plan',
      extra: CreatePlanArgs(
        cubit: context.read<TrainingPlansCubit>(),
        initialSelectedDays: days,
      ),
    );
  }

  void _editPlan(CustomTrainingPlan plan) {
    context.push(
      '/app/training/create-plan',
      extra: CreatePlanArgs(
        cubit: context.read<TrainingPlansCubit>(),
        existingPlan: plan,
      ),
    );
  }

  Future<void> _startPlan(CustomTrainingPlan plan) =>
      startPlanWorkout(context, plan);

  Future<void> _showPlanActions(CustomTrainingPlan plan) async {
    final action = await showModalBottomSheet<_PlanAction>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
                child: Text(
                  plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.textPrimary,
                ),
                title: const Text(
                  'Edytuj plan',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(_PlanAction.edit),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.strengthWeak,
                ),
                title: const Text(
                  'Usuń plan',
                  style: TextStyle(
                    color: AppColors.strengthWeak,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.of(sheetContext).pop(_PlanAction.delete),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _PlanAction.edit:
        _editPlan(plan);
      case _PlanAction.delete:
        await _confirmDelete(plan);
    }
  }

  Future<void> _confirmDelete(CustomTrainingPlan plan) async {
    final cubit = context.read<TrainingPlansCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Usunąć plan?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '„${plan.name}” zniknie z listy planów. Historia treningów '
          'pozostanie bez zmian.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Usuń',
              style: TextStyle(color: AppColors.strengthWeak),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.removePlan(plan.id);
  }

  List<CustomTrainingPlan> _visiblePlans(List<CustomTrainingPlan> plans) {
    final filter = _dayFilter;
    if (filter != null) {
      return plans.where((p) => p.selectedDays.contains(filter)).toList();
    }
    // Dzisiejsze plany na górze, reszta w dotychczasowej kolejności.
    final today = _today;
    return [
      ...plans.where((p) => p.selectedDays.contains(today)),
      ...plans.where((p) => !p.selectedDays.contains(today)),
    ];
  }

  Widget _constrained(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainingPlansCubit, TrainingPlansState>(
      builder: (context, state) {
        final bottomPadding =
            AppSpacing.xl + MediaQuery.paddingOf(context).bottom;
        const gutter = AppSpacing.pageGutter;

        if (state.isLoading && state.plans.isEmpty) {
          return SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: gutter),
            child: _constrained(const PlansSkeleton()),
          );
        }

        if (state.plans.isEmpty) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, bottomPadding),
            child: _constrained(PlansEmptyState(onCreate: _createPlan)),
          );
        }

        final today = _today;
        final visible = _visiblePlans(state.plans);
        final filter = _dayFilter;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: gutter),
              sliver: SliverToBoxAdapter(
                child: _constrained(
                  PlansWeekCard(
                    plans: state.plans,
                    selectedDay: filter,
                    onDaySelected: _toggleDay,
                    now: widget.now,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                gutter,
                AppSpacing.xl,
                gutter,
                AppSpacing.sm,
              ),
              sliver: SliverToBoxAdapter(
                child: _constrained(
                  _SectionHeader(
                    title: filter == null
                        ? 'Twoje plany'
                        : kTrainingWeekdayFullNames[filter - 1],
                    count: visible.length,
                    onClear: filter == null
                        ? null
                        : () => setState(() => _dayFilter = null),
                  ),
                ),
              ),
            ),
            if (visible.isEmpty && filter != null)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, bottomPadding),
                sliver: SliverToBoxAdapter(
                  child: _constrained(
                    PlansDayEmptyState(
                      dayName: kTrainingWeekdayFullNames[filter - 1],
                      onCreate: () => _createPlan(days: [filter]),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, bottomPadding),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final plan = visible[index];
                    return _constrained(
                      PlanCard(
                        key: ValueKey('plan-card-${plan.id}'),
                        plan: plan,
                        isToday: plan.selectedDays.contains(today),
                        onTap: () => _openPlan(plan),
                        onStart: () => _startPlan(plan),
                        onMore: () => _showPlanActions(plan),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

enum _PlanAction { edit, delete }

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    this.onClear,
  });

  final String title;
  final int count;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Spacer(),
          if (onClear != null)
            TextButton.icon(
              onPressed: onClear,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryVariant,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Wszystkie'),
            ),
        ],
      ),
    );
  }
}
