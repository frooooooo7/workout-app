import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/units/weight_unit.dart';
import '../../../../training/presentation/widgets/session_details/session_details_formatters.dart';
import '../../../../training/presentation/widgets/stats/stats_format.dart';
import '../../../domain/models/exercise_stats.dart';

/// Co pokazuje wykres historii ćwiczenia.
enum ExerciseChartMetric {
  oneRepMax('Szac. 1RM'),
  topWeight('Ciężar'),
  volume('Objętość'),
  maxReps('Powtórzenia'),
  sets('Serie');

  const ExerciseChartMetric(this.label);

  final String label;

  bool get _isWeight =>
      this == oneRepMax || this == topWeight || this == volume;

  /// Ciężary w aktualnej jednostce (kg / lb).
  String? get unit => _isWeight
      ? WeightUnits.current.label
      : (this == maxReps ? 'powt.' : null);

  /// Metryki z sensem dla ćwiczenia: z ciężarem albo z masą ciała.
  static List<ExerciseChartMetric> forStats(ExerciseStats stats) =>
      stats.hasWeights
      ? const [oneRepMax, topWeight, volume]
      : const [maxReps, sets];

  /// Wartość punktu — ciężary już w aktualnej jednostce.
  double valueOf(ExerciseSessionPoint point) => switch (this) {
    oneRepMax => WeightUnits.current.fromKg(point.estimatedOneRepMaxKg),
    topWeight => WeightUnits.current.fromKg(point.topWeightKg),
    volume => WeightUnits.current.fromKg(point.volumeKg),
    maxReps => point.maxReps.toDouble(),
    sets => point.sets.toDouble(),
  };

  /// [value] w jednostce z [valueOf].
  String format(double value) => switch (this) {
    oneRepMax => '${formatDisplayNumber((value * 2).round() / 2)} $unit',
    topWeight => '${formatDisplayNumber(value)} $unit',
    volume => formatVolumeKg(WeightUnits.current.toKg(value)),
    maxReps => '${value.round()} powt.',
    sets => '${value.round()}',
  };

  String get title => switch (this) {
    oneRepMax => 'Progres szacowanego 1RM',
    topWeight => 'Najcięższa seria',
    volume => 'Objętość na trening',
    maxReps => 'Najwięcej powtórzeń w serii',
    sets => 'Serie na trening',
  };
}

/// Wykres historii ćwiczenia z przełącznikiem metryki. Punkty idą co trening
/// (równe odstępy), dotknięcie pokazuje datę i wartość.
class ExerciseProgressChart extends StatefulWidget {
  const ExerciseProgressChart({super.key, required this.stats});

  /// Co najmniej dwa treningi w [ExerciseStats.history].
  final ExerciseStats stats;

  /// Tyle ostatnich treningów mieści się czytelnie na wykresie.
  static const maxPoints = 30;

  @override
  State<ExerciseProgressChart> createState() => _ExerciseProgressChartState();
}

class _ExerciseProgressChartState extends State<ExerciseProgressChart> {
  late ExerciseChartMetric _metric = ExerciseChartMetric.forStats(
    widget.stats,
  ).first;

  @override
  void didUpdateWidget(ExerciseProgressChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final metrics = ExerciseChartMetric.forStats(widget.stats);
    if (!metrics.contains(_metric)) _metric = metrics.first;
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.stats.history;
    final points = all.length > ExerciseProgressChart.maxPoints
        ? all.sublist(all.length - ExerciseProgressChart.maxPoints)
        : all;
    final values = [for (final p in points) _metric.valueOf(p)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricSelector(
          metrics: ExerciseChartMetric.forStats(widget.stats),
          selected: _metric,
          onSelected: (metric) => setState(() => _metric = metric),
        ),
        const SizedBox(height: 14),
        _ChartHeader(metric: _metric, first: values.first, last: values.last),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: _LineChart(
            key: ValueKey(_metric),
            points: points,
            values: values,
            metric: _metric,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _AxisLabel(date: points.first.date),
            if (all.length > points.length)
              Text('ostatnie ${points.length} treningów', style: _axisStyle),
            _AxisLabel(date: points.last.date),
          ],
        ),
      ],
    );
  }
}

const _axisStyle = TextStyle(
  color: AppColors.textMuted,
  fontSize: 10.5,
  fontWeight: FontWeight.w500,
);

class _MetricSelector extends StatelessWidget {
  const _MetricSelector({
    required this.metrics,
    required this.selected,
    required this.onSelected,
  });

  final List<ExerciseChartMetric> metrics;
  final ExerciseChartMetric selected;
  final ValueChanged<ExerciseChartMetric> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.chartTrack,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          for (final metric in metrics)
            Expanded(
              child: GestureDetector(
                key: ValueKey('exercise-chart-metric-${metric.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(metric),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: metric == selected
                        ? AppColors.surfaceVariant
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm + 1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    metric.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: metric == selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: metric == selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartHeader extends StatelessWidget {
  const _ChartHeader({
    required this.metric,
    required this.first,
    required this.last,
  });

  final ExerciseChartMetric metric;
  final double first;
  final double last;

  @override
  Widget build(BuildContext context) {
    final delta = last - first;
    final rounded = (delta * 2).round() / 2;
    final positive = rounded > 0;
    final negative = rounded < 0;
    final color = positive
        ? AppColors.success
        : negative
        ? AppColors.strengthWeak
        : AppColors.textMuted;
    final sign = positive ? '+' : (negative ? '−' : '±');
    final magnitude = metric == ExerciseChartMetric.volume
        ? formatVolumeKg(WeightUnits.current.toKg(rounded.abs()))
        : '${formatDisplayNumber(rounded.abs())}'
              '${metric.unit == null ? '' : ' ${metric.unit}'}';
    final text = rounded == 0 ? '±0' : '$sign$magnitude';

    return Row(
      children: [
        Expanded(
          child: Text(
            metric.title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                positive
                    ? Icons.trending_up_rounded
                    : negative
                    ? Icons.trending_down_rounded
                    : Icons.trending_flat_rounded,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({
    super.key,
    required this.points,
    required this.values,
    required this.metric,
  });

  final List<ExerciseSessionPoint> points;
  final List<double> values;
  final ExerciseChartMetric metric;

  static const _color = AppColors.primaryVariant;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    // Płaska seria (ten sam wynik) rysuje się pośrodku, a nie przy krawędzi.
    final pad = math.max((hi - lo) * 0.08, hi == 0 ? 1.0 : hi * 0.05);
    // Okrągły krok osi (1, 2, 2,5, 5 × 10ⁿ) — podpisy typu 80, 85, 90.
    final yInterval = _niceStep((hi - lo + pad * 2) / 3);
    final minY = math.max(
      0.0,
      ((lo - pad) / yInterval).floorToDouble() * yInterval,
    );
    final maxY = ((hi + pad) / yInterval).ceilToDouble() * yInterval;
    final recordIndexes = {
      for (var i = 0; i < points.length; i++)
        if (points[i].isRecord) i,
    };

    return LineChart(
      duration: const Duration(milliseconds: 250),
      LineChartData(
        minX: 0,
        maxX: math.max(spots.length - 1, 1).toDouble(),
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.none(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.chartGrid,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(_axisValue(value), style: _axisStyle),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
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
                  '${formatStatsDayMonth(points[t.spotIndex].date.toLocal())}\n',
                  const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(
                      text: metric.format(values[t.spotIndex]),
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
            barWidth: 2.5,
            isCurved: true,
            curveSmoothness: 0.2,
            preventCurveOverShooting: true,
            dotData: FlDotData(
              getDotPainter: (spot, _, _, index) {
                final last = index == spots.length - 1;
                final record =
                    recordIndexes.contains(index) &&
                    (metric == ExerciseChartMetric.topWeight ||
                        metric == ExerciseChartMetric.maxReps);
                return FlDotCirclePainter(
                  radius: last || record ? 4.5 : 3,
                  color: record ? AppColors.statAmber : _color,
                  strokeColor: AppColors.surface,
                  strokeWidth: 1.6,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _color.withValues(alpha: 0.26),
                  _color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static double _niceStep(double raw) {
    if (raw <= 0) return 1;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    for (final factor in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (raw <= factor * magnitude) return factor * magnitude;
    }
    return 10 * magnitude;
  }

  String _axisValue(double value) {
    if (metric == ExerciseChartMetric.volume && value >= 1000) {
      final suffix = WeightUnits.current == WeightUnit.kg ? ' t' : 'k';
      return '${formatStatsDecimal(value / 1000)}$suffix';
    }
    return formatStatsDecimal(value);
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) =>
      Text(formatExerciseHistoryDate(date), style: _axisStyle);
}

/// `12 wrz`, a dla innego roku `12 wrz 2025`.
String formatExerciseHistoryDate(DateTime date, {DateTime? now}) {
  final local = date.toLocal();
  final base = formatStatsDayMonth(local);
  return local.year == (now ?? DateTime.now()).year
      ? base
      : '$base ${local.year}';
}
