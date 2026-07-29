import 'package:flutter/material.dart';

import '../../domain/models/custom_training_plan.dart';
import 'training_day_hero.dart';
import 'training_day_status.dart';
import 'training_week_strip.dart';

class TrainingTodayPlanSection extends StatelessWidget {
  const TrainingTodayPlanSection({
    super.key,
    required this.selectedDay,
    required this.plans,
    required this.isLoading,
    required this.onDaySelected,
    required this.onOpenPlan,
    required this.onStartPlan,
    required this.onCreatePlanForDay,
  });

  final int selectedDay;
  final List<CustomTrainingPlan> plans;
  final bool isLoading;
  final ValueChanged<int> onDaySelected;
  final ValueChanged<CustomTrainingPlan> onOpenPlan;
  /// Kept for parent API parity; session start lives in plan details, not hero.
  // ignore: unused_field
  final Future<void> Function(CustomTrainingPlan plan) onStartPlan;
  final ValueChanged<int> onCreatePlanForDay;

  @override
  Widget build(BuildContext context) {
    final scheduledPlans = plans
        .where((plan) => plan.selectedDays.contains(selectedDay))
        .toList();
    final scheduledPlan = scheduledPlans.isEmpty ? null : scheduledPlans.first;
    final today = DateTime.now();
    final selectedDate =
        startOfWeekContaining(today).add(Duration(days: selectedDay - 1));
    final isRest = scheduledPlan == null;
    final subtitle = isRest
        ? 'Regeneracja to postęp.'
        : '${scheduledPlan.name}${scheduledPlans.length > 1 ? ' +${scheduledPlans.length - 1}' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TrainingDayHero(
          label: trainingDayHeroLabel(selectedDate, today: today),
          isLoading: isLoading,
          isRestDay: isRest,
          title: isRest ? 'Dzień odpoczynku' : 'Dzień treningowy',
          subtitle: subtitle,
          onTap: () {
            if (isLoading) return;
            final plan = scheduledPlan;
            if (plan == null) {
              onCreatePlanForDay(selectedDay);
            } else {
              onOpenPlan(plan);
            }
          },
        ),
        const SizedBox(height: 18),
        TrainingWeekStrip(
          selectedDay: selectedDay,
          onDaySelected: onDaySelected,
        ),
      ],
    );
  }
}
