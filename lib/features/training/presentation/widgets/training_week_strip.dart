import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'training_day_status.dart';

enum WeekDayMarker { empty, scheduled, completed }

class TrainingWeekStrip extends StatelessWidget {
  const TrainingWeekStrip({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
    this.scheduledWeekdays = const {},
    this.completedWeekdays = const {},
    this.today,
  });

  /// 1 = Monday … 7 = Sunday.
  final int selectedDay;
  final ValueChanged<int> onDaySelected;
  final Set<int> scheduledWeekdays;
  final Set<int> completedWeekdays;
  final DateTime? today;

  WeekDayMarker _markerFor(int weekday) {
    if (completedWeekdays.contains(weekday)) return WeekDayMarker.completed;
    if (scheduledWeekdays.contains(weekday)) return WeekDayMarker.scheduled;
    return WeekDayMarker.empty;
  }

  @override
  Widget build(BuildContext context) {
    final now = today ?? DateTime.now();
    final weekStart = startOfWeekContaining(now);

    return Row(
      children: List.generate(7, (i) {
        final weekday = i + 1;
        final date = weekStart.add(Duration(days: i));
        final isSelected = weekday == selectedDay;
        final marker = _markerFor(weekday);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _WeekDayCard(
              key: ValueKey('week-day-$weekday'),
              label: kTrainingWeekdayShortLabels[i],
              dayNumber: date.day,
              isSelected: isSelected,
              marker: marker,
              indicatorKey: ValueKey(
                'week-indicator-$weekday-${marker.name}',
              ),
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
    required this.marker,
    required this.indicatorKey,
    required this.onTap,
  });

  final String label;
  final int dayNumber;
  final bool isSelected;
  final WeekDayMarker marker;
  final Key indicatorKey;
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
        child: AnimatedScale(
          scale: isSelected ? 1.04 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : AppColors.surfaceVariant.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.border.withValues(alpha: 0.3),
                width: isSelected ? 1.6 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
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
                  marker: marker,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayIndicator extends StatelessWidget {
  const _DayIndicator({
    super.key,
    required this.marker,
  });

  final WeekDayMarker marker;

  @override
  Widget build(BuildContext context) {
    switch (marker) {
      case WeekDayMarker.completed:
        return Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        );
      case WeekDayMarker.scheduled:
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
        );
      case WeekDayMarker.empty:
        return const SizedBox(width: 7, height: 7);
    }
  }
}
