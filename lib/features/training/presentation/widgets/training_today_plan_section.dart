import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/training_day_plan.dart';
import 'training_plan_card.dart';
import 'training_rest_day_card.dart';
import 'training_week_strip.dart';

class TrainingTodayPlanSection extends StatelessWidget {
  const TrainingTodayPlanSection({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final int selectedDay;
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final plan = kTrainingPlansByWeekday[selectedDay];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Twój plan na dziś',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            GestureDetector(
              onTap: () {},
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
          child: plan != null
              ? TrainingPlanCard(key: ValueKey(selectedDay), plan: plan)
              : TrainingRestDayCard(key: ValueKey(selectedDay)),
        ),
        const SizedBox(height: 12),
        TrainingWeekStrip(
          selectedDay: selectedDay,
          workoutDays: kTrainingWorkoutWeekdays,
          onDaySelected: onDaySelected,
        ),
      ],
    );
  }
}
