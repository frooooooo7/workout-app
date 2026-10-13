import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/units/weight_unit.dart';
import '../../domain/models/body_weight_entry.dart';
import '../../domain/services/body_weight_trend.dart';
import 'body_weight_trend_chart.dart';

/// Masa ciała w czasie. Pełna wersja to [BodyWeightTrendChart] (trend,
/// pomiary, cel, dotyk); [compact] — sama linia pomiarów bez osi i dotyku
/// (karta w Statystykach). Wymaga co najmniej dwóch pomiarów, od
/// najstarszego.
class BodyWeightChart extends StatelessWidget {
  const BodyWeightChart({
    super.key,
    required this.entries,
    this.compact = false,
    this.trendKg,
    this.goalKg,
  }) : assert(entries.length >= 2, 'need at least two entries');

  final List<BodyWeightEntry> entries;
  final bool compact;

  /// Wartości trendu dla [entries] (np. liczone z całej historii, żeby
  /// początek okresu miał tło); domyślnie liczone z samych [entries].
  final List<double>? trendKg;
  final double? goalKg;

  static const _color = AppColors.statTeal;

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return BodyWeightTrendChart(
        entries: entries,
        trendKg: trendKg ?? bodyWeightSmoothedTrend(entries),
        goalKg: goalKg,
      );
    }
    final unit = WeightUnits.current;
    final first = entries.first.date;
    final spots = [
      for (final e in entries)
        FlSpot(
          bodyWeightDaysBetween(first, e.date).toDouble(),
          unit.fromKg(e.weightKg),
        ),
    ];
    final values = [for (final s in spots) s.y];
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final pad = math.max((hi - lo) * 0.25, 0.5);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(spots.last.x, 1.0),
        minY: (lo - pad).floorToDouble(),
        maxY: (hi + pad).ceilToDouble(),
        clipData: const FlClipData.horizontal(),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: _color,
            barWidth: 2,
            isCurved: true,
            curveSmoothness: 0.2,
            preventCurveOverShooting: true,
            dotData: const FlDotData(show: false),
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

/// `−1,2 kg`, `+0,4 kg`, `0 kg` (albo w funtach `+0,9 lb`) — znak zawsze
/// widoczny przy zmianie.
String formatWeightChange(double kg) {
  if (kg == 0) return '0 ${WeightUnits.current.label}';
  final sign = kg > 0 ? '+' : '−';
  return '$sign${formatWeightWithUnit(kg.abs())}';
}
