import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/training_day_plan.dart';

class TrainingWeekStrip extends StatelessWidget {
  const TrainingWeekStrip({
    super.key,
    required this.selectedDay,
    required this.workoutDays,
    required this.onDaySelected,
  });

  final int selectedDay;
  final Set<int> workoutDays;
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    final startOfWeek = DateTime.now().subtract(Duration(days: today - 1));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(7, (i) {
          final weekday = i + 1;
          final date = startOfWeek.add(Duration(days: i));
          final isToday = weekday == today;
          final isSelected = weekday == selectedDay;
          final hasWorkout = workoutDays.contains(weekday);

          return TrainingWeekDayChip(
            label: kTrainingWeekdayShortLabels[i],
            day: date.day,
            isToday: isToday,
            isSelected: isSelected,
            hasWorkout: hasWorkout,
            onTap: () => onDaySelected(weekday),
          );
        }),
      ),
    );
  }
}

class TrainingWeekDayChip extends StatelessWidget {
  const TrainingWeekDayChip({
    super.key,
    required this.label,
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.hasWorkout,
    required this.onTap,
  });

  final String label;
  final int day;
  final bool isToday;
  final bool isSelected;
  final bool hasWorkout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = isSelected || isToday;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlighted ? Colors.white : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: highlighted ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : isToday
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : Colors.transparent,
              shape: BoxShape.circle,
              border: isToday && !isSelected
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      width: 1.5,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : highlighted
                        ? AppColors.primary
                        : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: hasWorkout
                  ? (isSelected ? Colors.white : AppColors.primary)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
