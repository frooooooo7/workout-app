import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../training/presentation/widgets/stats/stats_format.dart';
import '../../domain/models/body_weight_entry.dart';
import '../utils/profile_details_labels.dart';

/// Linia masy ciała w czasie — oś X w dniach, więc przerwy między pomiarami
/// są widoczne. [compact] to wersja bez osi i dotyku (karta w Statystykach).
/// Wymaga co najmniej dwóch pomiarów, od najstarszego.
class BodyWeightChart extends StatelessWidget {
  const BodyWeightChart({
    super.key,
    required this.entries,
    this.compact = false,
  }) : assert(entries.length >= 2, 'need at least two entries');

  final List<BodyWeightEntry> entries;
  final bool compact;

  static const _color = AppColors.statTeal;

  double _dayOf(DateTime date) {
    final first = entries.first.date;
    // UTC — zmiana czasu nie przesuwa punktów o godzinę.
    return DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(first.year, first.month, first.day))
        .inDays
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    // Oś Y w jednostce, którą widzi użytkownik — podziałka wypada na
    // okrągłych liczbach także w funtach.
    final unit = WeightUnits.current;
    final spots = [
      for (final e in entries) FlSpot(_dayOf(e.date), unit.fromKg(e.weightKg)),
    ];
    final values = [for (final s in spots) s.y];
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final pad = math.max((hi - lo) * 0.25, 0.5);
    final minY = (lo - pad).floorToDouble();
    final maxY = (hi + pad).ceilToDouble();
    final maxX = math.max(spots.last.x, 1.0);
    final yInterval = math.max((maxY - minY) / 3, 0.5);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.horizontal(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: !compact,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.chartGrid,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: compact
            ? const FlTitlesData(show: false)
            : FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: yInterval,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.max || value == meta.min) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        space: 6,
                        child: Text(
                          formatDisplayNumber(value),
                          style: _axisStyle,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: math.max(maxX / 3, 1),
                    getTitlesWidget: (value, meta) {
                      final first = entries.first.date;
                      final date = DateTime(
                        first.year,
                        first.month,
                        first.day + value.round(),
                      );
                      return SideTitleWidget(
                        meta: meta,
                        space: 6,
                        fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                        child: Text(
                          formatStatsDayMonth(date),
                          style: _axisStyle,
                        ),
                      );
                    },
                  ),
                ),
              ),
        lineTouchData: compact
            ? const LineTouchData(enabled: false)
            : LineTouchData(
                handleBuiltInTouches: true,
                getTouchedSpotIndicator: (bar, indexes) => [
                  for (final _ in indexes)
                    TouchedSpotIndicatorData(
                      FlLine(
                        color: _color.withValues(alpha: 0.4),
                        strokeWidth: 1,
                        dashArray: const [3, 3],
                      ),
                      FlDotData(
                        getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                          radius: 5,
                          color: _color,
                          strokeColor: AppColors.textPrimary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                ],
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surfaceVariant,
                  tooltipBorder: const BorderSide(color: AppColors.border),
                  tooltipBorderRadius: BorderRadius.circular(AppRadius.sm),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (touched) => [
                    for (final t in touched)
                      LineTooltipItem(
                        '${formatStatsDayMonth(entries[t.spotIndex].date)}\n',
                        const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(
                            text: formatWeightKg(entries[t.spotIndex].weightKg),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: _color,
            barWidth: compact ? 2 : 2.5,
            isCurved: true,
            curveSmoothness: 0.2,
            preventCurveOverShooting: true,
            dotData: FlDotData(
              show: !compact && spots.length <= 40,
              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                radius: 3,
                color: _color,
                strokeColor: AppColors.surface,
                strokeWidth: 1.5,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _color.withValues(alpha: 0.22),
                  _color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _axisStyle = TextStyle(
  color: AppColors.textMuted,
  fontSize: 10.5,
  fontWeight: FontWeight.w500,
  fontFeatures: [FontFeature.tabularFigures()],
);

/// `−1,2 kg`, `+0,4 kg`, `0 kg` (albo w funtach `+0,9 lb`) — znak zawsze
/// widoczny przy zmianie.
String formatWeightChange(double kg) {
  if (kg == 0) return '0 ${WeightUnits.current.label}';
  final sign = kg > 0 ? '+' : '−';
  return '$sign${formatWeightWithUnit(kg.abs())}';
}
