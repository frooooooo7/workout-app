import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../training/presentation/widgets/stats/stats_format.dart';
import '../../domain/models/body_measurement_entry.dart';
import '../utils/body_measurement_format.dart';

/// Wiersz wpisu w historii pomiarów (testy).
Key bodyMeasurementEntryKey(DateTime date) =>
    ValueKey('body-measurements-entry-$date');

/// Wpis z jednego dnia: data i zmierzone wartości w siatce. Dotknięcie —
/// edycja, „Więcej” albo przytrzymanie — menu (edycja, usuwanie).
class BodyMeasurementEntryTile extends StatelessWidget {
  const BodyMeasurementEntryTile({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onMore,
  });

  final BodyMeasurementEntry entry;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final measured = [
      for (final field in BodyMeasurementField.values)
        if (entry[field] case final value?) (field: field, value: value),
    ];
    final summary = [
      for (final m in measured)
        '${measurementShortLabel(m.field)} ${formatMeasurement(m.field, m.value)}',
    ].join(', ');
    return Semantics(
      label: '${formatStatsLongDate(entry.date)}: $summary',
      child: InkWell(
        onTap: onTap,
        onLongPress: onMore,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        formatStatsLongDate(entry.date),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Cztery kolumny — wartości w tej samej kolumnie
                        // w każdym wpisie, jak w tabeli.
                        final cellWidth =
                            (constraints.maxWidth - 3 * _cellGap) / 4;
                        return Wrap(
                          spacing: _cellGap,
                          runSpacing: 8,
                          children: [
                            for (final m in measured)
                              SizedBox(
                                width: cellWidth,
                                child: _ValueCell(
                                  field: m.field,
                                  value: m.value,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Więcej',
                onPressed: onMore,
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _cellGap = 8.0;

class _ValueCell extends StatelessWidget {
  const _ValueCell({required this.field, required this.value});

  final BodyMeasurementField field;
  final double value;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            measurementShortLabel(field),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatMeasurementFixed(value),
                  style: AppTextStyles.number(size: 17, height: 1.25),
                ),
                TextSpan(
                  text: field.isPercent ? '%' : ' cm',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
