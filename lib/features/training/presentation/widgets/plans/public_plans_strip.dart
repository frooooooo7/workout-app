import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/plan_colors.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../../core/widgets/app_pressable.dart';
import '../../../domain/models/custom_training_plan.dart';
import 'plan_card.dart' show planMuscleFocus;

/// Poziomy pasek publicznych planów na profilu innej osoby.
class PublicPlansStrip extends StatelessWidget {
  const PublicPlansStrip({
    super.key,
    required this.plans,
    required this.onOpen,
  });

  final List<CustomTrainingPlan> plans;
  final ValueChanged<CustomTrainingPlan> onOpen;

  static const _cardWidth = 232.0;
  static const _height = 124.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
        itemCount: plans.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final plan = plans[index];
          return SizedBox(
            width: _cardWidth,
            child: _PublicPlanCard(
              key: ValueKey('public-plan-${plan.id}'),
              plan: plan,
              onTap: () => onOpen(plan),
            ),
          );
        },
      ),
    );
  }
}

class _PublicPlanCard extends StatelessWidget {
  const _PublicPlanCard({super.key, required this.plan, required this.onTap});

  final CustomTrainingPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = PlanColors.of(plan.name, colorKey: plan.colorKey);
    final exercises = plan.exercises.length;
    final sets = plan.exercises.fold(0, (sum, e) => sum + e.sets.length);
    final muscles = planMuscleFocus(plan, limit: 2);
    final copies = plan.copyCount;
    return AppPressable(
      onTap: onTap,
      pressedScale: 0.97,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                ...muscles,
                '$exercises ${polishPlural(exercises, 'ćwiczenie', 'ćwiczenia', 'ćwiczeń')}',
                '$sets ${polishPlural(sets, 'seria', 'serie', 'serii')}',
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.copy_rounded, size: 14, color: color),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    copies == 0
                        ? 'Podgląd i kopia'
                        : 'skopiowany $copies '
                              '${polishPlural(copies, 'raz', 'razy', 'razy')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
