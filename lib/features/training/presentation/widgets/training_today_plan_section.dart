import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/custom_training_plan.dart';
import 'training_plan_card.dart';
import 'training_rest_day_card.dart';
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
  final Future<void> Function(CustomTrainingPlan plan) onStartPlan;
  final ValueChanged<int> onCreatePlanForDay;

  @override
  Widget build(BuildContext context) {
    final scheduledPlans = plans
        .where((plan) => plan.selectedDays.contains(selectedDay))
        .toList();
    final workoutDays = plans.expand((plan) => plan.selectedDays).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Twoj plan na dzis',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (scheduledPlans.length == 1)
              GestureDetector(
                onTap: () => onOpenPlan(scheduledPlans.first),
                child: const Row(
                  children: [
                    Text(
                      'Zobacz plan',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _TodayPlanContent(
            key: ValueKey(
              'today-plan-$selectedDay-${scheduledPlans.length}-$isLoading',
            ),
            selectedDay: selectedDay,
            isLoading: isLoading,
            plans: scheduledPlans,
            onOpenPlan: onOpenPlan,
            onStartPlan: onStartPlan,
            onCreatePlanForDay: onCreatePlanForDay,
          ),
        ),
        const SizedBox(height: 12),
        TrainingWeekStrip(
          selectedDay: selectedDay,
          workoutDays: workoutDays,
          onDaySelected: onDaySelected,
        ),
      ],
    );
  }
}

class _TodayPlanContent extends StatelessWidget {
  const _TodayPlanContent({
    super.key,
    required this.selectedDay,
    required this.isLoading,
    required this.plans,
    required this.onOpenPlan,
    required this.onStartPlan,
    required this.onCreatePlanForDay,
  });

  final int selectedDay;
  final bool isLoading;
  final List<CustomTrainingPlan> plans;
  final ValueChanged<CustomTrainingPlan> onOpenPlan;
  final Future<void> Function(CustomTrainingPlan plan) onStartPlan;
  final ValueChanged<int> onCreatePlanForDay;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 112,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (plans.isEmpty) {
      return TrainingRestDayCard(
        onCreatePlan: () => onCreatePlanForDay(selectedDay),
      );
    }

    return Column(
      children: [
        for (final plan in plans)
          Padding(
            padding: EdgeInsets.only(bottom: plan == plans.last ? 0 : 12),
            child: TrainingPlanCard(
              plan: plan,
              onOpen: () => onOpenPlan(plan),
              onStart: () => onStartPlan(plan),
            ),
          ),
      ],
    );
  }
}
