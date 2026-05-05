import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/training_summary_stats.dart';

class TrainingSummaryPeriodToggle extends StatelessWidget {
  const TrainingSummaryPeriodToggle({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ActivitySummaryPeriod selected;
  final ValueChanged<ActivitySummaryPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: ActivitySummaryPeriod.values
            .map(
              (p) => Expanded(
                child: _PeriodOptionChip(
                  period: p,
                  isSelected: p == selected,
                  onTap: () => onChanged(p),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PeriodOptionChip extends StatelessWidget {
  const _PeriodOptionChip({
    required this.period,
    required this.isSelected,
    required this.onTap,
  });

  final ActivitySummaryPeriod period;
  final bool isSelected;
  final VoidCallback onTap;

  String get _label => switch (period) {
        ActivitySummaryPeriod.week => 'Tydzień',
        ActivitySummaryPeriod.month => 'Miesiąc',
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: AppColors.border) : null,
        ),
        alignment: Alignment.center,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
          child: Text(_label),
        ),
      ),
    );
  }
}
