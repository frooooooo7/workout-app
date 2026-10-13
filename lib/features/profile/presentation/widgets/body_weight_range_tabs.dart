import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/services/body_weight_trend.dart';

/// Tło wybranej zakładki — jaśniejsze niż karta, bez akcentu koloru.
const _selectedColor = Color(0xFF222A3C);

/// Zakładki okresu wykresu: 30 dni, 3 mies., Rok, Całość.
class BodyWeightRangeTabs extends StatelessWidget {
  const BodyWeightRangeTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final BodyWeightRange selected;
  final ValueChanged<BodyWeightRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final range in BodyWeightRange.values) ...[
            if (range.index > 0) const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                selected: range == selected,
                button: true,
                child: GestureDetector(
                  key: ValueKey('body-weight-range-${range.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (range == selected) return;
                    HapticFeedback.selectionClick();
                    onChanged(range);
                  },
                  child: AnimatedContainer(
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: range == selected
                          ? _selectedColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      range.label,
                      style: TextStyle(
                        color: range == selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: range == selected
                            ? FontWeight.w800
                            : FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
