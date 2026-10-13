import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/units/weight_unit.dart';
import '../utils/body_weight_format.dart';

/// Trzy liczby pod aktualną wagą: średnia 7 dni, tempo na tydzień
/// i przewidywana data celu. Prognoza znika, gdy trend prowadzi w złą
/// stronę albo nie ma celu.
class BodyWeightStatTiles extends StatelessWidget {
  const BodyWeightStatTiles({
    super.key,
    required this.averageKg,
    required this.pacePerWeekKg,
    required this.today,
    this.paceTowardGoal = false,
    this.goalDate,
  });

  final double averageKg;

  /// `null` — za mało pomiarów, żeby policzyć tempo.
  final double? pacePerWeekKg;
  final bool paceTowardGoal;
  final DateTime? goalDate;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final unit = WeightUnits.current.label;
    final pace = pacePerWeekKg;
    final date = goalDate;
    final tiles = [
      _Tile(
        key: const Key('body-weight-average'),
        label: 'Średnia 7 dni',
        value: formatWeightNumber(averageKg),
        unit: unit,
      ),
      _Tile(
        key: const Key('body-weight-pace'),
        label: 'Tempo',
        value: pace == null ? '—' : formatBodyWeightPace(pace),
        unit: pace == null ? null : '$unit/tydz.',
        valueColor: paceTowardGoal ? AppColors.success : AppColors.textPrimary,
      ),
      if (date != null)
        _Tile(
          key: const Key('body-weight-goal-date'),
          label: 'Cel około',
          value: formatBodyWeightGoalDate(date, today),
        ),
    ];
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.valueColor = AppColors.textPrimary,
  });

  final String label;
  final String value;
  final String? unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: value,
                children: [
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: AppTextStyles.number(
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              style: AppTextStyles.number(size: 23, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
