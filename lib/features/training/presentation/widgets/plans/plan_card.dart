import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../../core/widgets/app_pressable.dart';
import '../../../../library/domain/models/exercise.dart';
import '../../../domain/models/custom_training_plan.dart';
import '../training_day_status.dart';

/// Karta planu na liście: partie mięśni, podgląd ćwiczeń, dni tygodnia
/// i szybki start treningu.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.isToday,
    required this.onTap,
    required this.onStart,
    required this.onMore,
  });

  final CustomTrainingPlan plan;

  /// Plan zaplanowany na dziś — wyróżniona ramka i plakietka „Dziś”.
  final bool isToday;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final VoidCallback onMore;

  static const _previewCount = 3;

  @override
  Widget build(BuildContext context) {
    final exerciseCount = plan.exercises.length;
    final setCount = plan.exercises.fold(0, (sum, e) => sum + e.sets.length);
    final muscles = planMuscleFocus(plan);
    final note = plan.note?.trim() ?? '';
    final hiddenCount = exerciseCount - _previewCount;

    return AppPressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: isToday
                ? AppColors.primary.withValues(alpha: 0.55)
                : AppColors.border.withValues(alpha: 0.7),
          ),
          boxShadow: isToday
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xxs,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isToday) ...[
                          const _TodayBadge(),
                          const SizedBox(height: AppSpacing.xs),
                        ],
                        Text(
                          plan.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '$exerciseCount ${polishPlural(exerciseCount, 'ćwiczenie', 'ćwiczenia', 'ćwiczeń')}'
                          ' · $setCount ${polishPlural(setCount, 'seria', 'serie', 'serii')}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: ValueKey('plan-more-${plan.id}'),
                    tooltip: 'Więcej opcji',
                    onPressed: onMore,
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (muscles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final m in muscles) _MuscleChip(label: m)],
                ),
              ),
            if (exerciseCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    children: [
                      for (final (index, exercise)
                          in plan.exercises.take(_previewCount).indexed)
                        _ExercisePreviewRow(
                          index: index + 1,
                          exercise: exercise,
                        ),
                      if (hiddenCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 4),
                          child: Row(
                            children: [
                              const SizedBox(width: 30),
                              Text(
                                '+$hiddenCount więcej',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
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
            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.sticky_note_2_outlined,
                        color: AppColors.textMuted,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: _PlanWeekdays(
                      planId: plan.id,
                      selectedDays: plan.selectedDays,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _StartButton(
                    key: ValueKey('plan-start-${plan.id}'),
                    onPressed: exerciseCount == 0 ? null : onStart,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Do trzech głównych partii mięśni planu, ważonych liczbą serii.
List<String> planMuscleFocus(CustomTrainingPlan plan, {int limit = 3}) {
  final weights = <MuscleGroup, int>{};
  for (final entry in plan.exercises) {
    final groups = entry.exercise.muscles
        .where((m) => m != MuscleGroup.all)
        .map((m) => m.apiGroup)
        .toSet();
    for (final group in groups) {
      weights[group] = (weights[group] ?? 0) + entry.sets.length.clamp(1, 99);
    }
  }
  final sorted = weights.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [for (final e in sorted.take(limit)) e.key.label];
}

class _TodayBadge extends StatelessWidget {
  const _TodayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: AppColors.primaryVariant, size: 13),
          SizedBox(width: 3),
          Text(
            'DZIŚ',
            style: TextStyle(
              color: AppColors.primaryVariant,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ExercisePreviewRow extends StatelessWidget {
  const _ExercisePreviewRow({required this.index, required this.exercise});

  final int index;
  final PlanExercise exercise;

  @override
  Widget build(BuildContext context) {
    final sets = exercise.sets.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              exercise.exercise.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sets×',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanWeekdays extends StatelessWidget {
  const _PlanWeekdays({required this.planId, required this.selectedDays});

  final String planId;
  final List<int> selectedDays;

  static const _labels = ['P', 'W', 'Ś', 'C', 'P', 'S', 'N'];

  @override
  Widget build(BuildContext context) {
    final selected = selectedDays.toSet();
    if (selected.isEmpty) {
      return const Row(
        children: [
          Icon(Icons.event_busy_rounded, color: AppColors.textMuted, size: 15),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Bez stałych dni',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
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
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var day = 1; day <= 7; day++)
              Padding(
                padding: EdgeInsets.only(right: day == 7 ? 0 : 4),
                child: _WeekdayPill(
                  key: ValueKey(
                    'plan-day-$planId-$day-'
                    '${selected.contains(day) ? 'selected' : 'idle'}',
                  ),
                  label: _labels[day - 1],
                  selected: selected.contains(day),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayPill extends StatelessWidget {
  const _WeekdayPill({super.key, required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.22)
            : Colors.transparent,
        shape: BoxShape.circle,
        border: selected
            ? null
            : Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? AppColors.primaryVariant : AppColors.textMuted,
          fontSize: 10.5,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.surfaceVariant,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          padding: const EdgeInsets.only(left: 12, right: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        icon: const Icon(Icons.play_arrow_rounded, size: 20),
        label: const Text('Start'),
      ),
    );
  }
}
