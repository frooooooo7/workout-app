import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/units/weight_unit.dart';
import '../../../domain/services/history_feed_builder.dart';
import '../../../../library/domain/models/exercise_tracking.dart';

/// Najlepsza seria ćwiczenia: `92,5 kg × 5`, `12 powt.`, `3,2 km · 18:10`.
/// Rekord na złoto.
class HistoryLineValue extends StatelessWidget {
  const HistoryLineValue({super.key, required this.line, this.size = 20});

  final HistoryFeedLine line;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = line.isRecord ? AppColors.record : AppColors.textPrimary;
    final number = AppTextStyles.number(size: size, color: color, height: 1.1);
    final unit = TextStyle(
      color: line.isRecord
          ? AppColors.record.withValues(alpha: 0.75)
          : AppColors.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );

    final spans = <InlineSpan>[];
    final weight = line.weightKg;
    final reps = line.reps;
    if (line.durationSeconds != null || line.distanceM != null) {
      final distance = line.distanceM;
      final duration = line.durationSeconds;
      spans.add(
        TextSpan(
          text: [
            if (distance != null) line.distanceUnit.formatWithUnit(distance),
            if (duration != null) formatSetDuration(duration),
          ].join(' · '),
          style: number.copyWith(fontSize: size - 2),
        ),
      );
    } else if (weight != null) {
      spans
        ..add(TextSpan(text: formatWeightNumber(weight), style: number))
        ..add(TextSpan(text: ' ${WeightUnits.current.label}', style: unit));
      if (reps != null) {
        spans
          ..add(TextSpan(text: ' × ', style: unit))
          ..add(TextSpan(text: '$reps', style: number));
      }
    } else if (reps != null) {
      spans
        ..add(TextSpan(text: '$reps', style: number))
        ..add(TextSpan(text: ' powt.', style: unit));
    } else {
      return const SizedBox.shrink();
    }
    return Text.rich(TextSpan(children: spans), maxLines: 1);
  }
}
