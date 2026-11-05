import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/polish_plural.dart';
import '../../data/plan_sharing_repository.dart';
import '../../domain/models/custom_training_plan.dart';
import '../bloc/training_plans_cubit.dart';
import '../bloc/training_session_cubit.dart';
import '../screens/create_plan_screen.dart';
import '../screens/plan_details_screen.dart';
import '../utils/start_workout.dart';
import '../../../../core/theme/plan_colors.dart';
import 'plans/plan_card.dart';
import 'plans/plan_cover_image.dart';
import 'plans/plans_states.dart';
import 'plans/plans_week_card.dart';
import 'training_day_status.dart';

class TrainingPlansTab extends StatefulWidget {
  const TrainingPlansTab({
    super.key,
    this.now,
    this.newPlanId,
    this.copyNotice,
  });

  /// Test seam dla „dzisiejszego” dnia tygodnia.
  final DateTime? now;

  /// Świeżo skopiowany plan — karta z etykietą „Nowy”.
  final ValueListenable<String?>? newPlanId;

  /// Kopia czekająca na komunikat „Plan dodany”; zakładka go pokazuje
  /// i czyści, gdy plan jest już na liście.
  final ValueNotifier<PlanCopyOutcome?>? copyNotice;

  @override
  State<TrainingPlansTab> createState() => _TrainingPlansTabState();
}

class _TrainingPlansTabState extends State<TrainingPlansTab> {
  static const _maxContentWidth = 620.0;

  /// Filtr listy po dniu tygodnia (1–7); `null` — wszystkie plany.
  int? _dayFilter;

  /// Tryb zmiany kolejności planów (przeciąganie za uchwyt).
  bool _reordering = false;

  int get _today => (widget.now ?? DateTime.now()).weekday;

  @override
  void initState() {
    super.initState();
    widget.copyNotice?.addListener(_showCopyNotice);
    widget.newPlanId?.addListener(_onNewPlanChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCopyNotice());
  }

  @override
  void dispose() {
    widget.copyNotice?.removeListener(_showCopyNotice);
    widget.newPlanId?.removeListener(_onNewPlanChanged);
    super.dispose();
  }

  void _onNewPlanChanged() {
    if (mounted) setState(() {});
  }

  void _showCopyNotice() {
    final notice = widget.copyNotice;
    final outcome = notice?.value;
    if (!mounted || notice == null || outcome == null) return;
    final plans = context.read<TrainingPlansCubit>().state.plans;
    final plan = plans.where((p) => p.id == outcome.plan.id).firstOrNull;
    // Lista jeszcze się nie odświeżyła — spróbujemy po kolejnym stanie.
    if (plan == null) return;
    notice.value = null;
    final skipped = outcome.skippedExercises;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  skipped == 0
                      ? 'Plan „${plan.name}” dodany'
                      : 'Plan „${plan.name}” dodany bez $skipped '
                            '${polishPlural(skipped, 'ćwiczenia', 'ćwiczeń', 'ćwiczeń')} '
                            'autora spoza Twojej biblioteki',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Edytuj',
            textColor: AppColors.primaryVariant,
            onPressed: () {
              if (mounted) _editPlan(plan);
            },
          ),
        ),
      );
  }

  void _setReordering(bool value) {
    if (_reordering == value) return;
    setState(() {
      _reordering = value;
      _dayFilter = null;
    });
  }

  void _onReorder(List<CustomTrainingPlan> plans, int oldIndex, int newIndex) {
    final ids = [for (final plan in plans) plan.id];
    ids.insert(newIndex, ids.removeAt(oldIndex));
    unawaited(context.read<TrainingPlansCubit>().reorderPlans(ids));
  }

  void _toggleDay(int day) {
    setState(() => _dayFilter = _dayFilter == day ? null : day);
  }

  void _openPlan(CustomTrainingPlan plan) {
    _clearNew(plan);
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

  /// Otwarty plan przestaje być „nowy”.
  void _clearNew(CustomTrainingPlan plan) {
    final newPlanId = widget.newPlanId;
    if (newPlanId is ValueNotifier<String?> && newPlanId.value == plan.id) {
      newPlanId.value = null;
    }
  }

  void _editPlan(CustomTrainingPlan plan) {
    _clearNew(plan);
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

  Widget _buildReorderList(List<CustomTrainingPlan> plans, double bottom) {
    const gutter = AppSpacing.pageGutter;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(gutter, 0, gutter, AppSpacing.sm),
          sliver: SliverToBoxAdapter(
            child: _constrained(
              _ReorderHeader(onDone: () => _setReordering(false)),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, bottom),
          sliver: SliverReorderableList(
            itemCount: plans.length,
            onReorderItem: (oldIndex, newIndex) =>
                _onReorder(plans, oldIndex, newIndex),
            proxyDecorator: (child, index, animation) => Material(
              color: Colors.transparent,
              elevation: 0,
              child: child,
            ),
            itemBuilder: (context, index) {
              final plan = plans[index];
              return KeyedSubtree(
                key: ValueKey('reorder-${plan.id}'),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: _constrained(_ReorderTile(plan: plan, index: index)),
                ),
              );
            },
          ),
        ),
      ],
    );
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
    final newPlanId = widget.newPlanId;
    return BlocConsumer<TrainingPlansCubit, TrainingPlansState>(
      listenWhen: (previous, current) =>
          widget.copyNotice?.value != null &&
          !identical(previous.plans, current.plans),
      listener: (_, _) => _showCopyNotice(),
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

        if (_reordering && state.plans.length > 1) {
          return _buildReorderList(state.plans, bottomPadding);
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
                    onReorder: filter == null && state.plans.length > 1
                        ? () => _setReordering(true)
                        : null,
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
                        isNew: plan.id == newPlanId?.value,
                        onTap: () => _openPlan(plan),
                        onStart: () => _startPlan(plan),
                        onMore: () => _showPlanActions(plan),
                        onSetDays: () => _editPlan(plan),
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
    this.onReorder,
  });

  final String title;
  final int count;
  final VoidCallback? onClear;

  /// Wejście w tryb zmiany kolejności; `null` — nie ma czego układać.
  final VoidCallback? onReorder;

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
          if (onReorder != null)
            TextButton.icon(
              key: const ValueKey('plans-reorder-start'),
              onPressed: onReorder,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSubtle,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.swap_vert_rounded, size: 18),
              label: const Text('Kolejność'),
            ),
        ],
      ),
    );
  }
}

class _ReorderHeader extends StatelessWidget {
  const _ReorderHeader({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Kolejność planów',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          FilledButton(
            key: const ValueKey('plans-reorder-done'),
            onPressed: onDone,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.16),
              foregroundColor: const Color(0xFF8FB2FF),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: const Text('Gotowe'),
          ),
        ],
      ),
    );
  }
}

/// Wiersz planu w trybie kolejności: znak, nazwa, skrót i uchwyt.
class _ReorderTile extends StatelessWidget {
  const _ReorderTile({required this.plan, required this.index});

  final CustomTrainingPlan plan;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = PlanColors.of(plan.name, colorKey: plan.colorKey);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        0,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          PlanThumb(plan: plan, color: color, size: 44, radius: AppRadius.md),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  PlanCard.summaryOf(plan),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Semantics(
              label: 'Przeciągnij, aby zmienić kolejność: ${plan.name}',
              child: const SizedBox(
                key: ValueKey('plans-reorder-handle'),
                width: 52,
                height: 48,
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
