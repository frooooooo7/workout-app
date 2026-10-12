import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../utils/body_measurement_format.dart';

const bodyMeasurementComparePillKey = Key('body-measurement-compare-pill');

/// Porównywane daty: `3 sie → 12 paź`. Przy jednym wpisie (from == to)
/// sama data, bez rozwijania.
class BodyMeasurementComparePill extends StatelessWidget {
  const BodyMeasurementComparePill({
    super.key,
    required this.from,
    required this.to,
    required this.today,
    this.onTap,
  });

  final DateTime from;
  final DateTime to;
  final DateTime today;

  /// Wybór dat; `null` — nie ma z czego wybierać.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 13.5,
      fontWeight: FontWeight.w800,
    );
    final single = from == to;
    return Semantics(
      button: onTap != null,
      label: single
          ? 'Pomiar z ${formatMeasurementDate(to, today)}'
          : 'Porównanie ${formatMeasurementDate(from, today)} '
                'i ${formatMeasurementDate(to, today)}, zmień daty',
      excludeSemantics: true,
      child: AppPressable(
        key: bodyMeasurementComparePillKey,
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              if (!single) ...[
                Text(formatMeasurementDate(from, today), style: textStyle),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              Text(formatMeasurementDate(to, today), style: textStyle),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
