import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'training_day_status.dart';

class TrainingWeekStrip extends StatelessWidget {
  const TrainingWeekStrip({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
    this.today,
  });

  /// 1 = Monday … 7 = Sunday.
  final int selectedDay;
  final ValueChanged<int> onDaySelected;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final now = today ?? DateTime.now();
    final weekStart = startOfWeekContaining(now);

    return Row(
      children: List.generate(7, (i) {
        final weekday = i + 1;
        final date = weekStart.add(Duration(days: i));
        final isSelected = weekday == selectedDay;
        final isPast = isCalendarDateBefore(date, now);

        final String indicatorSuffix;
        if (isSelected) {
          indicatorSuffix = 'selected';
        } else if (isPast) {
          indicatorSuffix = 'past';
        } else {
          indicatorSuffix = 'future';
        }

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _WeekDayCard(
              key: ValueKey('week-day-$weekday'),
              label: kTrainingWeekdayShortLabels[i],
              dayNumber: date.day,
              isSelected: isSelected,
              indicatorKey: ValueKey('week-indicator-$weekday-$indicatorSuffix'),
              isPast: isPast && !isSelected,
              onTap: () => onDaySelected(weekday),
            ),
          ),
        );
      }),
    );
  }
}

class _WeekDayCard extends StatelessWidget {
  const _WeekDayCard({
    super.key,
    required this.label,
    required this.dayNumber,
    required this.isSelected,
    required this.indicatorKey,
    required this.isPast,
    required this.onTap,
  });

  final String label;
  final int dayNumber;
  final bool isSelected;
  final Key indicatorKey;
  final bool isPast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label $dayNumber',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$dayNumber',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _DayIndicator(
                key: indicatorKey,
                isSelected: isSelected,
                isPast: isPast,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayIndicator extends StatelessWidget {
  const _DayIndicator({
    super.key,
    required this.isSelected,
    required this.isPast,
  });

  final bool isSelected;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    if (isSelected) {
      return Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      );
    }

    if (isPast) {
      return const Icon(
        Icons.check,
        size: 14,
        color: Colors.white,
      );
    }

    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppColors.textMuted,
        shape: BoxShape.circle,
      ),
    );
  }
}
