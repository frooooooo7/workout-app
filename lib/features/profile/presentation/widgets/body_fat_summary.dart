import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/body_measurement_entry.dart';
import '../utils/body_measurement_comparison.dart';
import '../utils/body_measurement_format.dart';
import '../utils/body_measurement_trend.dart';

const bodyFatSummaryKey = Key('body-fat-summary');

/// Tkanka tłuszczowa obok porównywanych dat: wartość z końca okresu
/// i zmiana jako strzałka w kolorze celu.
class BodyFatSummary extends StatelessWidget {
  const BodyFatSummary({super.key, required this.delta});

  final BodyMeasurementDelta delta;

  @override
  Widget build(BuildContext context) {
    const field = BodyMeasurementField.bodyFat;
    final change = delta.change;
    return Semantics(
      label:
          '${field.label} ${formatMeasurement(field, delta.value)}'
          '${change == null ? '' : ', zmiana ${formatMeasurementChange(field, change)}'}',
      excludeSemantics: true,
      child: Column(
        key: bodyFatSummaryKey,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            field.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${formatMeasurementFixed(delta.value)}%',
                style: AppTextStyles.number(size: 22, height: 1.15),
              ),
              if (change != null) ...[
                const SizedBox(width: 6),
                _ChangeBadge(change: change),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.change});

  final double change;

  @override
  Widget build(BuildContext context) {
    final color = measurementTrend(BodyMeasurementField.bodyFat, change).color;
    final arrow = change < 0
        ? '↓ '
        : change > 0
        ? '↑ '
        : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$arrow${formatMeasurementFixed(change.abs())}',
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
