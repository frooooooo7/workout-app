import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../training/presentation/widgets/stats/stats_format.dart';
import '../../domain/models/body_measurement_entry.dart';
import '../utils/body_measurement_comparison.dart';
import '../utils/body_measurement_format.dart';
import '../utils/body_measurement_trend.dart';
import 'body_measurement_chart.dart';

/// Przycisk wyboru pomiaru nad wykresem (testy).
Key bodyMeasurementFieldChipKey(BodyMeasurementField field) =>
    ValueKey('body-measurement-chip-${field.name}');

/// Wykres jednego pomiaru w czasie z wyborem pomiaru i zmianą od
/// pierwszego wpisu w kolorze celu.
class BodyMeasurementTrendCard extends StatelessWidget {
  const BodyMeasurementTrendCard({
    super.key,
    required this.entries,
    required this.selected,
    required this.onSelected,
  });

  /// Od najstarszego.
  final List<BodyMeasurementEntry> entries;
  final BodyMeasurementField selected;
  final ValueChanged<BodyMeasurementField> onSelected;

  @override
  Widget build(BuildContext context) {
    final measured = [
      for (final field in BodyMeasurementField.values)
        if (entries.any((e) => e[field] != null)) field,
    ];
    final series = bodyMeasurementSeries(entries, selected);
    final change = series.length < 2
        ? null
        : roundMeasurementChange(series.first.value, series.last.value);

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                for (final field in measured) ...[
                  _FieldChip(
                    key: bodyMeasurementFieldChipKey(field),
                    label: measurementShortLabel(field),
                    selected: field == selected,
                    onTap: () {
                      if (field == selected) return;
                      HapticFeedback.selectionClick();
                      onSelected(field);
                    },
                  ),
                  if (field != measured.last)
                    const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    selected.label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (change != null)
                  Text(
                    '${formatMeasurementChange(selected, change)}'
                    ' od ${formatStatsDayMonth(series.first.date)}',
                    key: const Key('body-measurements-change'),
                    style: TextStyle(
                      color: measurementTrend(selected, change).color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 190,
            child: series.length >= 2
                ? Padding(
                    padding: const EdgeInsets.only(left: 2, right: 16),
                    child: BodyMeasurementChart(
                      field: selected,
                      points: series,
                    ),
                  )
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Dodaj co najmniej dwa pomiary, żeby zobaczyć wykres.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FieldChip extends StatelessWidget {
  const _FieldChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.tile,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.borderStrong,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.textPrimary : AppColors.iconOnTile,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
