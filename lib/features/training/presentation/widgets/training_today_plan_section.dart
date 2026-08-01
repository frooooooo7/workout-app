import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
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
    this.completedWeekdays = const {},
  });

  final int selectedDay;
  final List<CustomTrainingPlan> plans;
  final bool isLoading;
  final ValueChanged<int> onDaySelected;
  final ValueChanged<CustomTrainingPlan> onOpenPlan;
  final Future<void> Function(CustomTrainingPlan plan) onStartPlan;
  final ValueChanged<int> onCreatePlanForDay;
  final Set<int> completedWeekdays;

  @override
  Widget build(BuildContext context) {
    final scheduledPlans = plans
        .where((plan) => plan.selectedDays.contains(selectedDay))
        .toList();
    final scheduledPlan = scheduledPlans.isEmpty ? null : scheduledPlans.first;
    final workoutDays = plans.expand((plan) => plan.selectedDays).toSet();
    final today = DateTime.now();
    final selectedDate =
        startOfWeekContaining(today).add(Duration(days: selectedDay - 1));
    final isRest = scheduledPlan == null;
    final subtitle = isRest
        ? 'Regeneracja'
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
        if (!isLoading && scheduledPlan != null) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: _AnimatedPressable(
              child: FilledButton(
                key: const ValueKey('start-workout-button'),
                onPressed: () => onStartPlan(scheduledPlan),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 22),
                    SizedBox(width: 6),
                    Text(
                      'Rozpocznij',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        TrainingWeekStrip(
          selectedDay: selectedDay,
          onDaySelected: onDaySelected,
          scheduledWeekdays: workoutDays,
          completedWeekdays: completedWeekdays,
        ),
      ],
    );
  }
}

class _AnimatedPressable extends StatefulWidget {
  const _AnimatedPressable({required this.child});

  final Widget child;

  @override
  State<_AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<_AnimatedPressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _controller.forward(),
      onPointerUp: (_) => _controller.reverse(),
      onPointerCancel: (_) => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

