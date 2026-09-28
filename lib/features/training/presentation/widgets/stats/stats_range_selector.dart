import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../domain/models/training_stats.dart';

/// Pigułka z zakresami statystyk; wybrany zakres podświetla się kolorem
/// głównym.
class StatsRangeSelector extends StatelessWidget {
  const StatsRangeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final StatsRange selected;
  final ValueChanged<StatsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final range in StatsRange.values)
            Expanded(
              child: _RangeOption(
                range: range,
                selected: range == selected,
                onTap: () {
                  if (range == selected) return;
                  HapticFeedback.selectionClick();
                  onChanged(range);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RangeOption extends StatelessWidget {
  const _RangeOption({
    required this.range,
    required this.selected,
    required this.onTap,
  });

  final StatsRange range;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Zakres ${range.label}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
            child: Text(range.label, maxLines: 1),
          ),
        ),
      ),
    );
  }
}
