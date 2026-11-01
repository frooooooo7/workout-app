import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/plan_colors.dart';
import '../../../../core/theme/plan_icons.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../../core/utils/polish_plural.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../library/domain/models/exercise_tracking.dart';
import '../../../library/presentation/screens/exercise_details_screen.dart';
import '../../../library/presentation/widgets/exercise_actions_sheet.dart';
import '../../domain/models/custom_training_plan.dart';
import '../../domain/services/plan_exercise_summary.dart';
import '../bloc/training_plans_cubit.dart';
import '../bloc/training_session_cubit.dart';
import '../utils/start_workout.dart';
import '../widgets/ongoing_workout/exercise_thumb.dart';
import '../widgets/ongoing_workout/rest_timer_controls.dart';
import '../widgets/plans/plan_cover_image.dart';
import '../widgets/training_day_status.dart';
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

/// Podgląd planu: nagłówek z okładką (albo kolorem planu), skrót w liczbach,
/// dni, cel i ćwiczenia w zwartej liście — serie dopiero po rozwinięciu.
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
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            );
          }
          return _PlanDetailsView(plan: currentPlan, args: args);
        },
      ),
    );
  }
}

class _PlanDetailsView extends StatelessWidget {
  const _PlanDetailsView({required this.plan, required this.args});

  final CustomTrainingPlan plan;
  final PlanDetailsArgs args;

  void _edit(BuildContext context) {
    context.push(
      '/app/training/create-plan',
      extra: CreatePlanArgs(cubit: args.cubit, existingPlan: plan),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = PlanColors.of(plan.name, colorKey: plan.colorKey);
    final blocks = _exerciseBlocks(plan);
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.pageGutter,
          AppSpacing.xs,
          AppSpacing.pageGutter,
          AppSpacing.md,
        ),
        child: SizedBox(
          height: 54,
          child: FilledButton.icon(
            key: const ValueKey('plan-details-start'),
            onPressed: plan.exercises.isEmpty
                ? null
                : () => startPlanWorkout(context, plan),
            icon: const Icon(Icons.play_arrow_rounded, size: 24),
            label: const Text('Rozpocznij trening'),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: PlanColors.onAccent(color),
              disabledBackgroundColor: AppColors.surfaceVariant,
              disabledForegroundColor: AppColors.textMuted,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          _PlanHeroBar(
            plan: plan,
            color: color,
            onBack: () => Navigator.of(context).maybePop(),
            onEdit: () => _edit(context),
            onMore: () => _showPlanActions(context, plan),
          ),
          SliverToBoxAdapter(
            child: _PlanSummary(plan: plan, color: color),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageGutter,
              AppSpacing.lg,
              AppSpacing.pageGutter,
              AppSpacing.xs,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Text('ĆWICZENIA', style: _eyebrow),
                  const SizedBox(width: AppSpacing.sm),
                  if (plan.exercises.length > 1)
                    Expanded(
                      child: Text(
                        'Stuknij, aby zobaczyć serie',
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _eyebrow.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageGutter,
              0,
              AppSpacing.pageGutter,
              AppSpacing.xl,
            ),
            sliver: SliverList.separated(
              itemCount: blocks.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final block = blocks[index];
                final plan = this.plan;
                Widget tile(int exerciseIndex, {bool grouped = false}) =>
                    _ExerciseTile(
                      key: ValueKey(plan.exercises[exerciseIndex].id),
                      plan: plan,
                      planExercise: plan.exercises[exerciseIndex],
                      color: color,
                      grouped: grouped,
                      onMore: () =>
                          _showExerciseActions(context, plan, exerciseIndex),
                    );
                if (block.group == null) return tile(block.indices.single);
                return _SupersetBlock(
                  letter: block.group!,
                  restSeconds: plan.restFor(plan.exercises[block.indices.last]),
                  children: [
                    for (final i in block.indices) tile(i, grouped: true),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

const _eyebrow = TextStyle(
  color: AppColors.textLabel,
  fontSize: 11.5,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.1,
);

/// Kolejne ćwiczenia z tą samą literą superserii w jednym bloku.
class _ExerciseBlock {
  const _ExerciseBlock(this.group, this.indices);

  final String? group;
  final List<int> indices;
}

List<_ExerciseBlock> _exerciseBlocks(CustomTrainingPlan plan) {
  final blocks = <_ExerciseBlock>[];
  var i = 0;
  while (i < plan.exercises.length) {
    final group = plan.exercises[i].supersetGroup;
    var end = i + 1;
    if (group != null) {
      while (end < plan.exercises.length &&
          plan.exercises[end].supersetGroup == group) {
        end++;
      }
    }
    blocks.add(_ExerciseBlock(group, [for (var k = i; k < end; k++) k]));
    i = end;
  }
  return blocks;
}

/// Zwijany nagłówek: okładka (albo kolor planu) z nazwą na dole, przyciski
/// wstecz / edycja / więcej na półprzezroczystych kółkach.
class _PlanHeroBar extends StatelessWidget {
  const _PlanHeroBar({
    required this.plan,
    required this.color,
    required this.onBack,
    required this.onEdit,
    required this.onMore,
  });

  final CustomTrainingPlan plan;
  final Color color;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onMore;

  static const _toolbar = 60.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final expanded = plan.hasCover ? 250.0 : 188.0;
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: _toolbar,
      expandedHeight: expanded,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final max = expanded + top;
          final min = _toolbar + top;
          final t = ((constraints.maxHeight - min) / (max - min)).clamp(
            0.0,
            1.0,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              _HeroBackground(plan: plan, color: color),
              // Zwinięty pasek jest jednolity i czytelny.
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: AppColors.background.withValues(alpha: 1 - t),
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.pageGutter,
                right: AppSpacing.pageGutter,
                bottom: AppSpacing.md,
                child: Opacity(
                  opacity: Curves.easeIn.transform(t),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.name,
                              key: const ValueKey('plan-hero-name'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _subtitle(plan),
                              style: const TextStyle(
                                color: AppColors.textSubtle,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: top,
                left: 0,
                right: 0,
                height: _toolbar,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      _RoundAction(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Wstecz',
                        onTap: onBack,
                      ),
                      Expanded(
                        child: Opacity(
                          opacity: Curves.easeIn.transform(1 - t),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            child: Text(
                              plan.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _RoundAction(
                        key: const ValueKey('plan-details-edit'),
                        icon: Icons.edit_outlined,
                        tooltip: 'Edytuj plan',
                        onTap: onEdit,
                      ),
                      const SizedBox(width: 6),
                      _RoundAction(
                        key: const ValueKey('plan-details-more'),
                        icon: Icons.more_horiz_rounded,
                        tooltip: 'Więcej',
                        onTap: onMore,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _subtitle(CustomTrainingPlan plan) {
    final parts = [
      ?plan.goal?.label,
      if (plan.exercises.isNotEmpty) '~${plan.estimatedMinutes} min',
      if (plan.copiedFrom?.handle case final handle?) 'od @$handle',
    ];
    return parts.join(' · ');
  }
}

class _HeroBackground extends StatelessWidget {
  const _HeroBackground({required this.plan, required this.color});

  final CustomTrainingPlan plan;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (plan.hasCover) {
      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.surfaceVariant),
          PlanCoverImage.of(plan, cacheWidth: 1200),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.35, 1],
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.05),
                  AppColors.background,
                ],
              ),
            ),
          ),
        ],
      );
    }
    final icon = PlanIcons.choices[plan.iconKey];
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.34), AppColors.background],
            ),
          ),
        ),
        Positioned(
          right: -14,
          top: 36,
          child: Opacity(
            opacity: 0.16,
            child: icon != null
                ? Icon(icon, size: 150, color: color)
                : Text(
                    plan.name.trim().isEmpty
                        ? '?'
                        : plan.name.trim().characters.first.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 150,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        pressedScale: 0.92,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.38),
          ),
          child: Icon(icon, size: 21, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

/// Pod nagłówkiem: trzy liczby, dni tygodnia, ustawienia i notatka.
class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.plan, required this.color});

  final CustomTrainingPlan plan;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final setCount = plan.exercises.fold(0, (sum, e) => sum + e.sets.length);
    final note = plan.note?.trim() ?? '';
    final progression = plan.planProgression;
    final chips = <(IconData, String)>[
      (
        Icons.timer_outlined,
        'Przerwa ${formatRestRemaining(Duration(seconds: plan.defaultRestSeconds))}',
      ),
      if (progression != null && !progression.isOff)
        (Icons.trending_up_rounded, 'Progresja: ${progression.method.label}'),
      if (!plan.showRir) (Icons.visibility_off_outlined, 'Bez RIR'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.xs,
        AppSpacing.pageGutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  value: '${plan.exercises.length}',
                  label: polishPlural(
                    plan.exercises.length,
                    'ćwiczenie',
                    'ćwiczenia',
                    'ćwiczeń',
                  ),
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _StatTile(
                  value: '$setCount',
                  label: polishPlural(setCount, 'seria', 'serie', 'serii'),
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _StatTile(
                  value: plan.exercises.isEmpty
                      ? '–'
                      : '~${plan.estimatedMinutes}',
                  label: 'min',
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _DaysRow(days: plan.selectedDays, color: color),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (icon, label) in chips)
                _InfoChip(icon: icon, label: label),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.7),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.sticky_note_2_outlined,
                      color: AppColors.textMuted,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(
                        color: AppColors.textSubtle,
                        fontSize: 13,
                        height: 1.45,
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
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: Color.lerp(color, Colors.white, 0.2),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DaysRow extends StatelessWidget {
  const _DaysRow({required this.days, required this.color});

  final List<int> days;
  final Color color;

  static const _labels = ['P', 'W', 'Ś', 'C', 'P', 'S', 'N'];

  @override
  Widget build(BuildContext context) {
    final selected = days.toSet();
    if (selected.isEmpty) {
      return const Row(
        children: [
          Icon(Icons.event_busy_rounded, color: AppColors.textMuted, size: 16),
          SizedBox(width: 6),
          Text(
            'Bez stałych dni',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    final names = [
      for (var day = 1; day <= 7; day++)
        if (selected.contains(day)) kTrainingWeekdayFullNames[day - 1],
    ];
    return Semantics(
      label: 'Dni treningowe: ${names.join(', ')}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var day = 1; day <= 7; day++)
            Expanded(
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected.contains(day)
                        ? color.withValues(alpha: 0.2)
                        : null,
                    border: Border.all(
                      color: selected.contains(day)
                          ? color
                          : AppColors.borderStrong,
                      width: selected.contains(day) ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    _labels[day - 1],
                    style: TextStyle(
                      color: selected.contains(day)
                          ? Color.lerp(color, Colors.white, 0.25)
                          : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSubtle,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Superseria: ćwiczenia w jednej ramce z paskiem w kolorze superserii.
class _SupersetBlock extends StatelessWidget {
  const _SupersetBlock({
    required this.letter,
    required this.restSeconds,
    required this.children,
  });

  final String letter;
  final int restSeconds;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.superset.withValues(alpha: 0.35)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg - 1),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: AppColors.superset),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                      child: Row(
                        children: [
                          Text(
                            'SUPERSERIA $letter',
                            style: const TextStyle(
                              color: AppColors.superset,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              'przerwa po rundzie '
                              '${formatRestRemaining(Duration(seconds: restSeconds))}',
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...children,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ćwiczenie w jednej linii: miniatura, nazwa i „4 × 8–10 · 60 kg”.
/// Stuknięcie rozwija tabelę serii.
class _ExerciseTile extends StatefulWidget {
  const _ExerciseTile({
    super.key,
    required this.plan,
    required this.planExercise,
    required this.color,
    required this.onMore,
    this.grouped = false,
  });

  final CustomTrainingPlan plan;
  final PlanExercise planExercise;
  final Color color;
  final VoidCallback onMore;

  /// W superserii: bez własnej ramki (ramkę daje blok).
  final bool grouped;

  @override
  State<_ExerciseTile> createState() => _ExerciseTileState();
}

class _ExerciseTileState extends State<_ExerciseTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final planExercise = widget.planExercise;
    final exercise = planExercise.exercise;
    // Wyłączony RIR / tempo w Ustawieniach planu chowa kolumnę, nawet gdy
    // serie mają stare wartości.
    final hasRir =
        plan.showRir &&
        planExercise.sets.any((s) => s.rir != null && s.rir!.isNotEmpty);
    final hasTempo =
        plan.showTempo &&
        planExercise.sets.any((s) => s.tempo != null && s.tempo!.isNotEmpty);
    final summary = planExerciseSummary(
      planExercise,
      formatWeight: (raw) => weightTextForInput(raw),
      weightUnitLabel: WeightUnits.current.label,
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          label: '${exercise.name}, $summary',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                children: [
                  ExerciseThumb(
                    imageUrl: exercise.imageUrl,
                    size: 44,
                    radius: 12,
                    cardio: exercise.tracking.isCardio,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          style: TextStyle(
                            color: Color.lerp(
                              widget.color,
                              AppColors.textSubtle,
                              0.45,
                            ),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: IconButton(
                      tooltip: 'Więcej',
                      padding: EdgeInsets.zero,
                      onPressed: widget.onMore,
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PlanSetTable(
                        exercise: planExercise,
                        hasRir: hasRir,
                        hasTempo: hasTempo,
                      ),
                      if (planExercise.supersetGroup == null)
                        Text(
                          'Przerwa po serii '
                          '${formatRestRemaining(Duration(seconds: plan.restFor(planExercise)))}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );

    if (widget.grouped) return body;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Material(color: Colors.transparent, child: body),
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
        message:
            '„${plan.name}” zniknie z listy planów. Historia treningów '
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
/// synchronizacja potraktowałaby je jako wiersze oryginału. Zachowuje wygląd,
/// przerwy, superserie i ustawienia; nie przenosi dni, okładki ani miejsca
/// na liście.
CustomTrainingPlan duplicatePlan(CustomTrainingPlan plan) {
  return CustomTrainingPlan(
    name: '${plan.name} (kopia)',
    note: plan.note,
    defaultRestSeconds: plan.defaultRestSeconds,
    colorKey: plan.colorKey,
    iconKey: plan.iconKey,
    goal: plan.goal,
    progressionStepKg: plan.progressionStepKg,
    progression: plan.progression,
    highlightPlanColor: plan.highlightPlanColor,
    showRir: plan.showRir,
    showTempo: plan.showTempo,
    exercises: [
      for (final planExercise in plan.exercises)
        PlanExercise(
          exercise: planExercise.exercise,
          restSeconds: planExercise.restSeconds,
          supersetGroup: planExercise.supersetGroup,
          sets: [
            for (final set in planExercise.sets)
              ExerciseSet(
                weight: set.weight,
                reps: set.reps,
                rir: set.rir,
                tempo: set.tempo,
                durationSeconds: set.durationSeconds,
                distanceM: set.distanceM,
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
        message:
            '„${planExercise.exercise.name}” i jego serie znikną z tego '
            'planu. Ćwiczenie zostanie w bibliotece.',
      );
      if (!confirmed || !context.mounted) return;
      await save([...plan.exercises]..removeAt(index));
  }
}

/// Tabela serii planu — kolumny zależą od tego, co ćwiczenie zapisuje:
/// ciężar i powtórzenia albo czas i dystans odcinków.
class _PlanSetTable extends StatelessWidget {
  const _PlanSetTable({
    required this.exercise,
    required this.hasRir,
    required this.hasTempo,
  });

  final PlanExercise exercise;
  final bool hasRir;
  final bool hasTempo;

  static const _headerStyle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
  );

  static const _valueStyle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static String _orDash(String? value) =>
      value != null && value.isNotEmpty ? value : '-';

  @override
  Widget build(BuildContext context) {
    final tracking = exercise.exercise.tracking;
    final unit = exercise.exercise.distanceUnit;
    final columns = <(String, String Function(ExerciseSet))>[
      if (tracking.tracksWeight)
        (
          'CIĘŻAR',
          (set) => set.weight != null && set.weight!.isNotEmpty
              ? '${weightTextForInput(set.weight)} ${WeightUnits.current.label}'
              : '-',
        ),
      if (tracking.tracksReps) ('POWT.', (set) => _orDash(set.reps)),
      if (tracking.tracksDuration)
        (
          'CZAS',
          (set) => set.durationSeconds == null
              ? '-'
              : formatSetDuration(set.durationSeconds!),
        ),
      if (tracking.tracksDistance)
        (
          'DYSTANS',
          (set) =>
              set.distanceM == null ? '-' : unit.formatWithUnit(set.distanceM!),
        ),
      if (hasRir && !tracking.isCardio) ('RIR', (set) => _orDash(set.rir)),
      if (hasTempo && !tracking.isCardio)
        ('TEMPO', (set) => _orDash(set.tempo)),
    ];

    Widget row(Widget first, List<Widget> cells) => Row(
      children: [
        SizedBox(width: 40, child: first),
        for (final cell in cells) ...[
          const SizedBox(width: 8),
          Expanded(child: cell),
        ],
      ],
    );

    return Column(
      children: [
        row(
          Text(
            tracking.isCardio ? 'ODC.' : 'SERIA',
            textAlign: TextAlign.center,
            style: _headerStyle,
          ),
          [
            for (final (header, _) in columns)
              Text(header, textAlign: TextAlign.center, style: _headerStyle),
          ],
        ),
        const SizedBox(height: 8),
        for (final (index, set) in exercise.sets.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: row(
              Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: _valueStyle,
              ),
              [
                for (final (_, value) in columns)
                  Text(
                    value(set),
                    textAlign: TextAlign.center,
                    style: _valueStyle,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
