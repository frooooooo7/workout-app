import 'package:flutter/material.dart';

import 'package:gym/core/theme/app_colors.dart';
import 'package:gym/core/widgets/app_pressable.dart';

/// Horizontal, borderless month timeline. Always shows as many whole months
/// as fit the available width — nothing is ever clipped at the edges — with
/// the focused month centered by default and after every selection.
class MonthSelectorBar extends StatelessWidget {
  const MonthSelectorBar({
    super.key,
    required this.availableMonths,
    required this.focusedMonth,
    required this.onMonthSelected,
  });

  final List<DateTime> availableMonths;
  final DateTime focusedMonth;
  final ValueChanged<DateTime> onMonthSelected;

  static const _monthNames = [
    'Sty',
    'Lut',
    'Mar',
    'Kwi',
    'Maj',
    'Cze',
    'Lip',
    'Sie',
    'Wrz',
    'Paź',
    'Lis',
    'Gru',
  ];

  static const _minItemWidth = 56.0;
  static const _horizontalPadding = 16.0;

  @override
  Widget build(BuildContext context) {
    if (availableMonths.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final window = _visibleWindow(constraints.maxWidth);
          return IntrinsicHeight(
            child: Row(
              children: [
                for (final monthDate in window)
                  Expanded(
                    child: _MonthItem(
                      key: ValueKey(monthDate),
                      monthLabel: _monthNames[monthDate.month - 1],
                      yearLabel: '${monthDate.year}',
                      isSelected: monthDate.year == focusedMonth.year &&
                          monthDate.month == focusedMonth.month,
                      onTap: () => onMonthSelected(monthDate),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Picks the widest odd-sized run of consecutive months that fits
  /// [availableWidth], centered on [focusedMonth] — so the active month
  /// lands in the middle slot by construction, with no partial items.
  List<DateTime> _visibleWindow(double availableWidth) {
    var visibleCount = (availableWidth / _minItemWidth).floor().clamp(1, availableMonths.length);
    if (visibleCount < availableMonths.length && visibleCount.isEven && visibleCount > 1) {
      visibleCount -= 1;
    }

    final focusedIndex = availableMonths.indexWhere(
      (m) => m.year == focusedMonth.year && m.month == focusedMonth.month,
    );
    final centerIndex = focusedIndex == -1 ? 0 : focusedIndex;

    final maxStart = availableMonths.length - visibleCount;
    final start = (centerIndex - visibleCount ~/ 2).clamp(0, maxStart < 0 ? 0 : maxStart);

    return availableMonths.sublist(start, start + visibleCount);
  }
}

class _MonthItem extends StatelessWidget {
  const _MonthItem({
    super.key,
    required this.monthLabel,
    required this.yearLabel,
    required this.isSelected,
    required this.onTap,
  });

  final String monthLabel;
  final String yearLabel;
  final bool isSelected;
  final VoidCallback onTap;

  static const _inactiveMonthColor = Color(0xFF8A93A6);
  static const _inactiveYearColor = Color(0xFF5B6376);
  static const _activeYearColor = Color(0xFFCBDCFF);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppPressable(
        onTap: onTap,
        pressedScale: 0.94,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 18 : 10,
            vertical: isSelected ? 6 : 8,
          ),
          constraints: const BoxConstraints(minWidth: 52),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary,
                      Color.lerp(AppColors.primary, Colors.black, 0.35)!,
                    ],
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: isSelected ? Colors.white : _inactiveMonthColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                  height: 1.15,
                ),
                child: Text(monthLabel, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 1),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: isSelected ? _activeYearColor : _inactiveYearColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                  height: 1.15,
                ),
                child: Text(yearLabel, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
