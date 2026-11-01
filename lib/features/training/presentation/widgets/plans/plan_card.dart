import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/plan_colors.dart';
import 'plan_cover_image.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../../core/widgets/app_pressable.dart';
import '../../../../library/domain/models/exercise.dart';
import '../../../domain/models/custom_training_plan.dart';
import '../training_day_status.dart';

/// Karta planu na liście: znak lub okładka, nazwa, skrót „5 ćw. · 18 serii
/// · ~55 min”, dni tygodnia i okrągły przycisk startu w kolorze planu.
/// Ćwiczenia, mięśnie i notatka są w podglądzie planu.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.isToday,
    required this.onTap,
    required this.onStart,
    required this.onMore,
    this.isNew = false,
    this.onSetDays,
  });

  final CustomTrainingPlan plan;

  /// Plan zaplanowany na dziś — wyróżniona ramka i plakietka „Dziś”.
  final bool isToday;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final VoidCallback onMore;

  /// Świeżo skopiowany plan — etykieta „Nowy”, ramka w kolorze planu
  /// i pasek „Ustaw dni”, dopóki plan nie ma dni.
  final bool isNew;
  final VoidCallback? onSetDays;

  /// Skrót planu: „5 ćw. · 18 serii · ~55 min”.
  static String summaryOf(CustomTrainingPlan plan) {
    final exerciseCount = plan.exercises.length;
    final setCount = plan.exercises.fold(0, (sum, e) => sum + e.sets.length);
    if (exerciseCount == 0) return 'Bez ćwiczeń';
    return '$exerciseCount ćw. · $setCount '
        '${polishPlural(setCount, 'seria', 'serie', 'serii')} · '
        '~${plan.estimatedMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final exerciseCount = plan.exercises.length;
    final color = PlanColors.of(plan.name, colorKey: plan.colorKey);
    final author = plan.copiedFrom;
    final showDaysPrompt =
        isNew && plan.selectedDays.isEmpty && onSetDays != null;
    final highlight = isNew ? color : (isToday ? AppColors.primary : null);

    return AppPressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: highlight != null
                ? highlight.withValues(alpha: 0.55)
                : AppColors.border.withValues(alpha: 0.7),
          ),
          boxShadow: highlight != null
              ? [
                  BoxShadow(
                    color: highlight.withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                PlanThumb(plan: plan, color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isToday || isNew) ...[
                        Row(
                          children: [
                            if (isToday) const _TodayBadge(),
                            if (isToday && isNew) const SizedBox(width: 6),
                            if (isNew) _NewBadge(color: color),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        plan.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summaryOf(plan),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (author != null) ...[
                        const SizedBox(height: 6),
                        PlanAuthorLabel(author: author),
                      ] else if (!showDaysPrompt) ...[
                        const SizedBox(height: 8),
                        _PlanWeekdays(
                          planId: plan.id,
                          selectedDays: plan.selectedDays,
                          color: color,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StartButton(
                      key: ValueKey('plan-start-${plan.id}'),
                      color: color,
                      onPressed: exerciseCount == 0 ? null : onStart,
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: 44,
                      height: 32,
                      child: IconButton(
                        key: ValueKey('plan-more-${plan.id}'),
                        tooltip: 'Więcej opcji',
                        padding: EdgeInsets.zero,
                        onPressed: onMore,
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (showDaysPrompt)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: _SetDaysPrompt(
                  key: ValueKey('plan-set-days-${plan.id}'),
                  onTap: onSetDays!,
                ),
              )
            else if (author != null && plan.selectedDays.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: _PlanWeekdays(
                  planId: plan.id,
                  selectedDays: plan.selectedDays,
                  color: color,
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
        .map((m) => m.broadGroup)
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

class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        'NOWY',
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// „od @anna” z inicjałem autora — przy planach skopiowanych od innej osoby.
class PlanAuthorLabel extends StatelessWidget {
  const PlanAuthorLabel({super.key, required this.author});

  final PlanAuthor author;

  @override
  Widget build(BuildContext context) {
    final handle = author.handle;
    final label = handle == null ? 'od innej osoby' : 'od @$handle';
    final initial = handle == null || handle.isEmpty
        ? '?'
        : handle.substring(0, 1).toUpperCase();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFF2A2350),
            shape: BoxShape.circle,
          ),
          child: Text(
            initial,
            style: const TextStyle(
              color: AppColors.planLegs,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSubtle,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pasek na świeżo skopiowanym planie bez dni: „Bez przypisanych dni”.
class _SetDaysPrompt extends StatelessWidget {
  const _SetDaysPrompt({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const amber = AppColors.statAmber;
    return Semantics(
      button: true,
      label: 'Bez przypisanych dni. Ustaw dni',
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        pressedScale: 0.98,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: amber.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: amber.withValues(alpha: 0.35)),
          ),
          child: const Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: amber, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bez przypisanych dni',
                  style: TextStyle(
                    color: AppColors.textSubtle,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Ustaw dni',
                style: TextStyle(
                  color: amber,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanWeekdays extends StatelessWidget {
  const _PlanWeekdays({
    required this.planId,
    required this.selectedDays,
    required this.color,
  });

  final String planId;
  final List<int> selectedDays;
  final Color color;

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
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayPill extends StatelessWidget {
  const _WeekdayPill({
    super.key,
    required this.label,
    required this.selected,
    required this.color,
  });

  final String label;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.2)
            : Colors.transparent,
        shape: BoxShape.circle,
        border: selected
            ? null
            : Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected
              ? Color.lerp(color, Colors.white, 0.25)
              : AppColors.textMuted,
          fontSize: 10.5,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({super.key, required this.color, required this.onPressed});

  /// Kolor planu — ten sam co w podglądzie „Wygląd planu”.
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Rozpocznij trening',
      excludeSemantics: true,
      child: AppPressable(
        onTap: onPressed,
        pressedScale: 0.92,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? color : AppColors.surfaceVariant,
          ),
          child: Icon(
            Icons.play_arrow_rounded,
            size: 26,
            color: enabled ? PlanColors.onAccent(color) : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
