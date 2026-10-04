import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../../library/data/exercise_image_uri.dart';
import '../../../library/presentation/screens/exercise_details_screen.dart';
import '../../../library/presentation/widgets/exercise_actions_sheet.dart';
import '../../domain/models/custom_training_plan.dart';
import '../bloc/training_plans_cubit.dart';
import '../bloc/training_session_cubit.dart';
import '../utils/start_workout.dart';
import '../widgets/plan_days_list.dart';
import '../widgets/plan_details_stats_card.dart';
import 'create_plan_screen.dart';

class PlanDetailsArgs {
  final CustomTrainingPlan plan;
  final TrainingPlansCubit cubit;
  final TrainingSessionCubit sessionCubit;

  const PlanDetailsArgs({
    required this.plan,
    required this.cubit,
    required this.sessionCubit,
  });
}

class PlanDetailsScreen extends StatelessWidget {
  const PlanDetailsScreen({super.key, required this.args});

  final PlanDetailsArgs args;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: args.cubit),
        BlocProvider.value(value: args.sessionCubit),
      ],
      child: BlocBuilder<TrainingPlansCubit, TrainingPlansState>(
        builder: (context, state) {
          final currentPlan = state.plans
              .cast<CustomTrainingPlan?>()
              .firstWhere((p) => p?.id == args.plan.id, orElse: () => null);

          if (currentPlan == null) {
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: Text(
                  'Nie znaleziono planu',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          }

          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.background,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                currentPlan.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    context.push(
                      '/app/training/create-plan',
                      extra: CreatePlanArgs(
                        cubit: args.cubit,
                        existingPlan: currentPlan,
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                ),
                IconButton(
                  tooltip: 'Więcej',
                  onPressed: () => _showPlanActions(context, currentPlan),
                  icon: const Icon(Icons.more_horiz, color: Colors.white),
                ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              minimum: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => startPlanWorkout(context, currentPlan),
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
            ),
            body: SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (currentPlan.selectedDays.isNotEmpty)
                          PlanDaysList(selectedDays: currentPlan.selectedDays),
                        PlanDetailsStatsCard(plan: currentPlan),
                        if (currentPlan.note != null &&
                            currentPlan.note!.isNotEmpty)
                          _NotesSection(note: currentPlan.note!),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
                          child: Text(
                            'Ćwiczenia',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final planExercise = currentPlan.exercises[index];
                      final hasRir = planExercise.sets.any(
                        (s) => s.rir != null && s.rir!.isNotEmpty,
                      );
                      final hasTempo = planExercise.sets.any(
                        (s) => s.tempo != null && s.tempo!.isNotEmpty,
                      );
                      return _ExerciseCard(
                        key: ValueKey(planExercise.id),
                        planExercise: planExercise,
                        hasRir: hasRir,
                        hasTempo: hasTempo,
                        onMore: () => _showExerciseActions(
                          context,
                          currentPlan,
                          index,
                        ),
                      );
                    }, childCount: currentPlan.exercises.length),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _PlanAction { edit, duplicate, delete }

enum _PlanExerciseAction { details, moveUp, moveDown, remove }

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

Future<void> _showPlanActions(
  BuildContext context,
  CustomTrainingPlan plan,
) async {
  final cubit = context.read<TrainingPlansCubit>();
  final action = await showAppActionSheet<_PlanAction>(
    context,
    title: plan.name,
    actions: const [
      AppSheetAction(
        value: _PlanAction.edit,
        icon: Icons.edit_outlined,
        label: 'Edytuj plan',
      ),
      AppSheetAction(
        value: _PlanAction.duplicate,
        icon: Icons.copy_rounded,
        label: 'Duplikuj plan',
        subtitle: 'Kopia bez przypisanych dni tygodnia',
      ),
      AppSheetAction(
        value: _PlanAction.delete,
        icon: Icons.delete_outline_rounded,
        label: 'Usuń plan',
        destructive: true,
      ),
    ],
  );
  if (!context.mounted || action == null) return;

  switch (action) {
    case _PlanAction.edit:
      context.push(
        '/app/training/create-plan',
        extra: CreatePlanArgs(cubit: cubit, existingPlan: plan),
      );
    case _PlanAction.duplicate:
      try {
        await cubit.addPlan(duplicatePlan(plan));
        if (context.mounted) _showMessage(context, 'Utworzono kopię planu.');
      } catch (_) {
        if (context.mounted) {
          _showMessage(context, 'Nie udało się zduplikować planu.');
        }
      }
    case _PlanAction.delete:
      final confirmed = await showAppConfirmDialog(
        context,
        title: 'Usunąć plan?',
        message: '„${plan.name}” zniknie z listy planów. Historia treningów '
            'pozostanie bez zmian.',
      );
      if (!confirmed || !context.mounted) return;
      // Najpierw zamykamy ekran — po usunięciu builder pokazałby
      // „Nie znaleziono planu”.
      context.pop();
      await cubit.removePlan(plan.id);
  }
}

/// Kopia planu z nowymi identyfikatorami ćwiczeń i serii — inaczej
/// synchronizacja potraktowałaby je jako wiersze oryginału.
CustomTrainingPlan duplicatePlan(CustomTrainingPlan plan) {
  return CustomTrainingPlan(
    name: '${plan.name} (kopia)',
    note: plan.note,
    exercises: [
      for (final planExercise in plan.exercises)
        PlanExercise(
          exercise: planExercise.exercise,
          sets: [
            for (final set in planExercise.sets)
              ExerciseSet(
                weight: set.weight,
                reps: set.reps,
                rir: set.rir,
                tempo: set.tempo,
              ),
          ],
        ),
    ],
  );
}

Future<void> _showExerciseActions(
  BuildContext context,
  CustomTrainingPlan plan,
  int index,
) async {
  final cubit = context.read<TrainingPlansCubit>();
  final planExercise = plan.exercises[index];
  final isFirst = index == 0;
  final isLast = index == plan.exercises.length - 1;

  final action = await showAppActionSheet<_PlanExerciseAction>(
    context,
    header: ExerciseSheetHeader(exercise: planExercise.exercise),
    actions: [
      const AppSheetAction(
        value: _PlanExerciseAction.details,
        icon: Icons.open_in_full_rounded,
        label: 'Karta ćwiczenia',
        subtitle: 'Mięśnie, opis i Twoje rekordy',
      ),
      AppSheetAction(
        value: _PlanExerciseAction.moveUp,
        icon: Icons.arrow_upward_rounded,
        label: 'Przesuń wyżej',
        enabled: !isFirst,
      ),
      AppSheetAction(
        value: _PlanExerciseAction.moveDown,
        icon: Icons.arrow_downward_rounded,
        label: 'Przesuń niżej',
        enabled: !isLast,
      ),
      const AppSheetAction(
        value: _PlanExerciseAction.remove,
        icon: Icons.remove_circle_outline_rounded,
        label: 'Usuń z planu',
        destructive: true,
      ),
    ],
  );
  if (!context.mounted || action == null) return;

  Future<void> save(List<PlanExercise> exercises) async {
    try {
      await cubit.updatePlan(plan.copyWith(exercises: exercises));
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'Nie udało się zapisać planu.');
      }
    }
  }

  switch (action) {
    case _PlanExerciseAction.details:
      await openExerciseDetails(context, planExercise.exercise);
    case _PlanExerciseAction.moveUp:
      final exercises = [...plan.exercises];
      exercises.insert(index - 1, exercises.removeAt(index));
      await save(exercises);
    case _PlanExerciseAction.moveDown:
      final exercises = [...plan.exercises];
      exercises.insert(index + 1, exercises.removeAt(index));
      await save(exercises);
    case _PlanExerciseAction.remove:
      final confirmed = await showAppConfirmDialog(
        context,
        title: 'Usunąć z planu?',
        message: '„${planExercise.exercise.name}” i jego serie znikną z tego '
            'planu. Ćwiczenie zostanie w bibliotece.',
      );
      if (!confirmed || !context.mounted) return;
      await save([...plan.exercises]..removeAt(index));
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              note,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  const _ExerciseCard({
    super.key,
    required this.planExercise,
    required this.hasRir,
    required this.hasTempo,
    required this.onMore,
  });

  final PlanExercise planExercise;
  final bool hasRir;
  final bool hasTempo;
  final VoidCallback onMore;

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final planExercise = widget.planExercise;
    final hasRir = widget.hasRir;
    final hasTempo = widget.hasTempo;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    image: switch (exerciseThumbProvider(
                      context,
                      planExercise.exercise.imageUrl,
                      logicalSize: 40,
                    )) {
                      final provider? => DecorationImage(
                        image: provider,
                        fit: BoxFit.cover,
                        onError: (_, _) {},
                      ),
                      null => null,
                    },
                  ),
                  child: planExercise.exercise.imageUrl == null
                      ? const Icon(
                          Icons.fitness_center,
                          color: AppColors.textMuted,
                          size: 22,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        planExercise.exercise.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${planExercise.sets.length} serie',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Więcej',
                  onPressed: widget.onMore,
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Expanded table
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  // Header row
                  Row(
                    children: [
                      const SizedBox(
                        width: 40,
                        child: Text(
                          'SERIA',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'CIĘŻAR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'POWT.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      if (hasRir) ...[
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'RIR',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                      if (hasTempo) ...[
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'TEMPO',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Set rows
                  ...planExercise.sets.asMap().entries.map((entry) {
                    final setIndex = entry.key;
                    final set = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${setIndex + 1}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              set.weight != null && set.weight!.isNotEmpty
                                  ? '${weightTextForInput(set.weight)} '
                                        '${WeightUnits.current.label}'
                                  : '-',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              set.reps.isNotEmpty ? set.reps : '-',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (hasRir) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                set.rir != null && set.rir!.isNotEmpty
                                    ? set.rir!
                                    : '-',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          if (hasTempo) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                set.tempo != null && set.tempo!.isNotEmpty
                                    ? set.tempo!
                                    : '-',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
