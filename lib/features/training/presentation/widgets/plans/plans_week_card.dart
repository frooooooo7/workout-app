import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../domain/models/custom_training_plan.dart';
import '../training_day_status.dart';

/// Tydzień planów: ile planów przypada na każdy dzień, dzisiejszy dzień
/// wyróżniony. Tap w dzień filtruje listę planów (ponowny tap czyści filtr).
class PlansWeekCard extends StatelessWidget {
  const PlansWeekCard({
    super.key,
    required this.plans,
    required this.selectedDay,
    required this.onDaySelected,
    this.now,
  });

  final List<CustomTrainingPlan> plans;

  /// 1 = poniedziałek … 7 = niedziela; `null` — bez filtra.
  final int? selectedDay;
  final ValueChanged<int> onDaySelected;

  /// Test seam dla podświetlenia dzisiejszego dnia.
  final DateTime? now;

  static const _dayLabels = ['P', 'W', 'Ś', 'C', 'P', 'S', 'N'];

  @override
  Widget build(BuildContext context) {
    final today = (now ?? DateTime.now()).weekday;
    final plansPerDay = List.generate(
      7,
      (index) => plans.where((p) => p.selectedDays.contains(index + 1)).length,
    );
    final trainingDays = plansPerDay.where((count) => count > 0).length;
    final exerciseCount = plans.fold(
      0,
      (sum, plan) => sum + plan.exercises.length,
    );
    final setCount = plans.fold(
      0,
      (sum, plan) => sum + plan.exercises.fold(0, (s, e) => s + e.sets.length),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(AppColors.surface, AppColors.heroGlow, 0.55)!,
            AppColors.surface,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Twój tydzień',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$trainingDays/7 dni z planem',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (var day = 1; day <= 7; day++)
                Expanded(
                  child: _WeekDayCell(
                    day: day,
                    label: _dayLabels[day - 1],
                    planCount: plansPerDay[day - 1],
                    isToday: day == today,
                    isSelected: day == selectedDay,
                    onTap: () => onDaySelected(day),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(height: 1, color: AppColors.border.withValues(alpha: 0.6)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: '${plans.length}',
                  label: polishPlural(plans.length, 'plan', 'plany', 'planów'),
                ),
              ),
              Expanded(
                child: _Metric(
                  value: '$exerciseCount',
                  label: polishPlural(
                    exerciseCount,
                    'ćwiczenie',
                    'ćwiczenia',
                    'ćwiczeń',
                  ),
                ),
              ),
              Expanded(
                child: _Metric(
                  value: '$setCount',
                  label: polishPlural(setCount, 'seria', 'serie', 'serii'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({
    required this.day,
    required this.label,
    required this.planCount,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final String label;
  final int planCount;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPlans = planCount > 0;
    final Color fill;
    final Color foreground;
    if (isSelected) {
      fill = AppColors.primary;
      foreground = AppColors.onPrimary;
    } else if (hasPlans) {
      fill = AppColors.primary.withValues(alpha: 0.18);
      foreground = AppColors.primaryVariant;
    } else {
      fill = AppColors.surfaceVariant.withValues(alpha: 0.6);
      foreground = AppColors.textMuted;
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label:
          '${kTrainingWeekdayFullNames[day - 1]}, '
          '$planCount ${polishPlural(planCount, 'plan', 'plany', 'planów')}'
          '${isToday ? ', dziś' : ''}',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('plans-week-day-$day'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isToday ? AppColors.textPrimary : AppColors.textMuted,
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: isToday && !isSelected
                    ? Border.all(color: AppColors.primaryVariant, width: 1.5)
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: hasPlans
                  ? Text(
                      '$planCount',
                      style: TextStyle(
                        color: foreground,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
