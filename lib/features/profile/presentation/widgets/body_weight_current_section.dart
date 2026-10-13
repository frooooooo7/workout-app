import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../../core/widgets/animated_number.dart';
import '../../domain/models/body_weight_entry.dart';
import '../../domain/services/body_weight_trend.dart';
import '../utils/body_weight_format.dart';

/// Aktualna waga: dzień pomiaru, duża liczba (dolicza się od początku
/// okresu) i zmiana od pierwszego pomiaru w okresie.
class BodyWeightCurrentSection extends StatelessWidget {
  const BodyWeightCurrentSection({
    super.key,
    required this.latest,
    required this.trend,
    required this.today,
    this.goal,
  });

  final BodyWeightEntry latest;

  /// `null`, gdy w okresie jest mniej niż dwa pomiary.
  final BodyWeightTrend? trend;
  final DateTime today;

  /// Kolorowanie zmiany: zielona, gdy przybliża do celu.
  final BodyWeightGoalProgress? goal;

  @override
  Widget build(BuildContext context) {
    final unit = WeightUnits.current;
    final t = trend;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatBodyWeightEyebrow(latest.date, today),
            style: AppTextStyles.eyebrow.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                // Duża liczba nie może wypchnąć zmiany za ekran.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      AnimatedNumber(
                        key: const Key('body-weight-current'),
                        value: unit.fromKg(latest.weightKg),
                        from: unit.fromKg(t?.first.weightKg ?? latest.weightKg),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutExpo,
                        format: (v) => _formatBig(v, unit),
                        style: AppTextStyles.number(
                          size: 64,
                        ).copyWith(letterSpacing: -0.64),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        unit.label,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (t != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _ChangePill(
                    changeKg: t.changeKg,
                    towardGoal: goal?.isTowardGoal(t.changeKg) ?? false,
                    caption: 'od ${formatBodyWeightSince(t.first.date, today)}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// `81,3` — w kilogramach zawsze z jednym miejscem, żeby liczba nie
  /// zmieniała szerokości w trakcie doliczania; funty bez ułamka.
  static String _formatBig(double value, WeightUnit unit) {
    if (unit == WeightUnit.lb) return value.round().toString();
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }
}

class _ChangePill extends StatelessWidget {
  const _ChangePill({
    required this.changeKg,
    required this.towardGoal,
    required this.caption,
  });

  final double changeKg;
  final bool towardGoal;
  final String caption;

  @override
  Widget build(BuildContext context) {
    // Bez celu kierunek nie jest oceniany — spadek nie zawsze jest dobry.
    final color = towardGoal ? AppColors.success : AppColors.iconOnTile;
    final icon = changeKg > 0
        ? Icons.arrow_upward_rounded
        : changeKg < 0
        ? Icons.arrow_downward_rounded
        : Icons.arrow_forward_rounded;
    final delta =
        '${formatBodyWeightDelta(changeKg)} ${WeightUnits.current.label}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                delta,
                key: const Key('body-weight-change'),
                semanticsLabel: changeKg < 0
                    ? 'Spadek o $delta'
                    : changeKg > 0
                    ? 'Wzrost o $delta'
                    : 'Bez zmian',
                style: AppTextStyles.tabular(
                  TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
