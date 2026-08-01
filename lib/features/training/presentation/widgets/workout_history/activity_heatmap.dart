import 'package:flutter/material.dart';

import 'package:gym/core/theme/app_colors.dart';
import 'package:gym/core/widgets/app_pressable.dart';

class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({
    super.key,
    required this.focusedMonth,
    required this.trainingDays,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final DateTime focusedMonth;
  final Set<DateTime> trainingDays;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  static const _fullMonthNames = [
    'styczniu',
    'lutym',
    'marcu',
    'kwietniu',
    'maju',
    'czerwcu',
    'lipcu',
    'sierpniu',
    'wrześniu',
    'październiku',
    'listopadzie',
    'grudniu',
  ];

  static const _monthNamesGenitive = [
    'stycznia',
    'lutego',
    'marca',
    'kwietnia',
    'maja',
    'czerwca',
    'lipca',
    'sierpnia',
    'września',
    'października',
    'listopada',
    'grudnia',
  ];

  /// Builds a grid matrix of 7 rows (Mon..Sun) by N week columns for the specified month.
  List<List<DateTime?>> _buildMonthMatrix(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    // Polish week start: Monday = 1, Sunday = 7
    final startWeekday = firstDay.weekday; // 1..7
    final firstDayRow = startWeekday - 1; // 0..6

    final totalCells = firstDayRow + daysInMonth;
    final totalWeeks = (totalCells / 7).ceil();

    final matrix = List.generate(
      7,
      (_) => List<DateTime?>.filled(totalWeeks, null),
    );

    int currentDay = 1;
    for (int week = 0; week < totalWeeks; week++) {
      for (int row = 0; row < 7; row++) {
        if (week == 0 && row < firstDayRow) {
          matrix[row][week] = null;
        } else if (currentDay <= daysInMonth) {
          matrix[row][week] = DateTime(month.year, month.month, currentDay);
          currentDay++;
        } else {
          matrix[row][week] = null;
        }
      }
    }

    return matrix;
  }

  bool _isTrainingDay(DateTime date) {
    return trainingDays.any((d) =>
        d.year == date.year && d.month == date.month && d.day == date.day);
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return now.year == date.year && now.month == date.month && now.day == date.day;
  }

  bool _isSelected(DateTime date) {
    if (selectedDay == null) return false;
    return selectedDay!.year == date.year &&
        selectedDay!.month == date.month &&
        selectedDay!.day == date.day;
  }

  @override
  Widget build(BuildContext context) {
    final matrix = _buildMonthMatrix(focusedMonth);
    final totalWeeks = matrix.isNotEmpty ? matrix[0].length : 0;
    final daysCount = trainingDays.length;
    final locMonthName = _fullMonthNames[focusedMonth.month - 1];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Aktywność',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (selectedDay != null)
                GestureDetector(
                  onTap: () => onDaySelected(selectedDay!),
                  child: const Text(
                    'Pokaż cały miesiąc',
                    style: TextStyle(
                      color: AppColors.primaryVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Heatmap Layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Weekday labels column (Pon, Śro, Pią)
              const Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _WeekdayLabel('Pon'),
                  SizedBox(height: 2),
                  _WeekdayLabel(''), // Wt
                  SizedBox(height: 2),
                  _WeekdayLabel('Śro'),
                  SizedBox(height: 2),
                  _WeekdayLabel(''), // Czw
                  SizedBox(height: 2),
                  _WeekdayLabel('Pią'),
                  SizedBox(height: 2),
                  _WeekdayLabel(''), // Sob
                  SizedBox(height: 2),
                  _WeekdayLabel(''), // Nie
                ],
              ),
              const SizedBox(width: 8),

              // Grid of week columns
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final availableWidth = constraints.maxWidth;
                    final gap = 4.0;
                    final cellSize = ((availableWidth - (gap * (totalWeeks - 1))) / totalWeeks)
                        .clamp(14.0, 24.0);

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: List.generate(totalWeeks, (weekIndex) {
                        return Padding(
                          padding: EdgeInsets.only(
                            right: weekIndex < totalWeeks - 1 ? gap : 0,
                          ),
                          child: Column(
                            children: List.generate(7, (rowIndex) {
                              final date = matrix[rowIndex][weekIndex];

                              if (date == null) {
                                return SizedBox(
                                  width: cellSize,
                                  height: cellSize + (rowIndex < 6 ? gap : 0),
                                );
                              }

                              final hasWorkout = _isTrainingDay(date);
                              final today = _isToday(date);
                              final selected = _isSelected(date);
                              final monthGenitive =
                                  _monthNamesGenitive[date.month - 1];
                              final semanticLabel =
                                  '${date.day} $monthGenitive ${date.year}, ${hasWorkout ? "trening wykonany" : "brak treningu"}';

                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: rowIndex < 6 ? gap : 0,
                                ),
                                child: Semantics(
                                  label: semanticLabel,
                                  button: true,
                                  selected: selected,
                                  child: AppPressable(
                                    onTap: () => onDaySelected(date),
                                    pressedScale: 0.90,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      width: cellSize,
                                      height: cellSize,
                                      decoration: BoxDecoration(
                                        color: hasWorkout
                                            ? AppColors.primary
                                            : AppColors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: selected
                                              ? Colors.white
                                              : (today
                                                  ? AppColors.primaryVariant
                                                  : (hasWorkout
                                                      ? AppColors.primary
                                                          .withValues(alpha: 0.8)
                                                      : AppColors.border
                                                          .withValues(alpha: 0.4))),
                                          width: selected ? 2.0 : (today ? 1.5 : 1.0),
                                        ),
                                        boxShadow: selected || (hasWorkout && today)
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 6,
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Summary line below heatmap
          Text(
            selectedDay != null
                ? 'Wybrano ${selectedDay!.day} ${_monthNamesGenitive[selectedDay!.month - 1]}'
                : '$daysCount ${daysCount == 1 ? 'dzień treningowy' : 'dni treningowych'} w $locMonthName',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      width: 24,
      child: Text(
        label,
        textAlign: TextAlign.start,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
