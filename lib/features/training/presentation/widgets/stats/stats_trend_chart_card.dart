import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/units/weight_unit.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../domain/models/training_stats.dart';
import '../../../domain/services/stats/training_stats_calculator.dart';
import '../session_details/session_section_card.dart';
import 'stats_format.dart';

/// Miara pokazywana na wykresie w czasie.
enum _TrendMetric {
  volume('Objętość', AppColors.statIndigo),
  sets('Serie', AppColors.statTeal),
  duration('Czas', AppColors.statOrange),
  workouts('Treningi', AppColors.primaryVariant);

  const _TrendMetric(this.label, this.color);

  final String label;
  final Color color;

  /// Wartość słupka w jednostce osi: kg (lb), serie, minuty, treningi.
  double valueOf(StatsSeriesPoint p) => switch (this) {
    _TrendMetric.volume => WeightUnits.current.fromKg(p.volumeKg),
    _TrendMetric.sets => p.sets.toDouble(),
    _TrendMetric.duration => p.durationSec / 60,
    _TrendMetric.workouts => p.workouts.toDouble(),
  };

  bool get isInteger =>
      this == _TrendMetric.sets || this == _TrendMetric.workouts;

  /// Pełna wartość do podsumowania i dymka.
  String format(double value) => switch (this) {
    _TrendMetric.volume => () {
      final v = formatStatsVolume(WeightUnits.current.toKg(value));
      return '${v.value} ${v.unit}';
    }(),
    _TrendMetric.sets => formatStatsDecimal(value),
    _TrendMetric.duration => formatStatsDurationShort((value * 60).round()),
    _TrendMetric.workouts => formatStatsDecimal(value),
  };

  /// Zwięzły podpis osi Y: „800 kg”, „1,5 t”, „20k lb”, „2 h”, „40”.
  String formatAxis(double value) {
    switch (this) {
      case _TrendMetric.volume:
        if (WeightUnits.current == WeightUnit.lb) {
          if (value >= 1000) return '${formatStatsDecimal(value / 1000)}k lb';
          return '${formatStatsDecimal(value)} lb';
        }
        if (value >= 1000) return '${formatStatsDecimal(value / 1000)} t';
        return '${formatStatsDecimal(value)} kg';
      case _TrendMetric.duration:
        // Do 2 h krok jest w minutach (15, 30…), więc „75 min” zamiast
        // zaokrąglonego „1,3 h”; wyżej krok to pełne półgodziny.
        if (value >= 60 && value % 60 == 0) return '${value ~/ 60} h';
        if (value > 120) return '${formatStatsDecimal(value / 60)} h';
        return '${value.round()} min';
      case _TrendMetric.sets:
      case _TrendMetric.workouts:
        return formatStatsDecimal(value);
    }
  }

  /// Podpis sumy z poprawną odmianą.
  String totalCaption(double total) => switch (this) {
    _TrendMetric.volume => 'łącznie podniesione',
    _TrendMetric.sets =>
      '${polishPlural(total.round(), 'seria', 'serie', 'serii')} łącznie',
    _TrendMetric.duration => 'łącznie na treningach',
    _TrendMetric.workouts =>
      '${polishPlural(total.round(), 'trening', 'treningi', 'treningów')} łącznie',
  };

  /// Krok siatki dla wartości do [max]. Czas powyżej 2 h idzie w pełnych
  /// półgodzinach, żeby podpisy były okrągłe.
  double gridStep(double max) {
    if (max <= 0) {
      return switch (this) {
        _TrendMetric.volume => 250,
        _TrendMetric.duration => 15,
        _ => 1,
      };
    }
    if (this == _TrendMetric.duration) {
      if (max > 120) return math.max(30, _niceStep(max / 60 / 4) * 60);
      for (final step in const [5.0, 10.0, 15.0, 20.0, 30.0]) {
        if (step >= max / 4) return step;
      }
      return 30;
    }
    final step = _niceStep(max / 4);
    return isInteger ? math.max(1, step.ceilToDouble()) : step;
  }
}

/// 1 / 2 / 2,5 / 5 × 10ⁿ — najbliższy „ładny” krok nie mniejszy niż [raw].
double _niceStep(double raw) {
  if (raw <= 0) return 1;
  final magnitude = math
      .pow(10, (math.log(raw) / math.ln10).floor())
      .toDouble();
  final normalized = raw / magnitude;
  final nice = normalized <= 1
      ? 1.0
      : normalized <= 2
      ? 2.0
      : normalized <= 2.5
      ? 2.5
      : normalized <= 5
      ? 5.0
      : 10.0;
  return nice * magnitude;
}

String _bucketNoun(StatsBucket bucket) => switch (bucket) {
  StatsBucket.day => 'dzień',
  StatsBucket.week => 'tydzień',
  StatsBucket.month => 'miesiąc',
  StatsBucket.year => 'rok',
};

String _currentBucketLabel(StatsBucket bucket) => switch (bucket) {
  StatsBucket.day => 'dziś',
  StatsBucket.week => 'bieżący tydzień',
  StatsBucket.month => 'bieżący miesiąc',
  StatsBucket.year => 'bieżący rok',
};

/// Okno średniej kroczącej. Docelowo tydzień dni / miesiąc tygodni / kwartał
/// miesięcy, ale na krótkiej serii (7 dni) pełne okno dałoby jeden punkt —
/// wtedy skracamy je do połowy serii.
int _averageWindow(StatsBucket bucket, int length) {
  final preferred = switch (bucket) {
    StatsBucket.day => 7,
    StatsBucket.week => 4,
    StatsBucket.month || StatsBucket.year => 3,
  };
  return math.min(preferred, length ~/ 2);
}

String _averageWindowLabel(StatsBucket bucket, int window) {
  final noun = switch (bucket) {
    StatsBucket.day => ('dzień', 'dni', 'dni'),
    StatsBucket.week => ('tydzień', 'tygodnie', 'tygodni'),
    StatsBucket.month => ('miesiąc', 'miesiące', 'miesięcy'),
    StatsBucket.year => ('rok', 'lata', 'lat'),
  };
  final word = polishPlural(window, noun.$1, noun.$2, noun.$3);
  return '$window $word';
}

/// Słupki wybranej miary w kolejnych przedziałach zakresu, z przerywaną
/// średnią kroczącą i podsumowaniem nad wykresem.
class StatsTrendChartCard extends StatefulWidget {
  const StatsTrendChartCard({super.key, required this.snapshot});

  final TrainingStatsSnapshot snapshot;

  @override
  State<StatsTrendChartCard> createState() => _StatsTrendChartCardState();
}

class _StatsTrendChartCardState extends State<StatsTrendChartCard> {
  _TrendMetric _metric = _TrendMetric.volume;

  @override
  Widget build(BuildContext context) {
    final series = widget.snapshot.series;
    final bucket = widget.snapshot.window.bucket;
    final values = [for (final p in series) _metric.valueOf(p)];
    final total = values.fold<double>(0, (sum, v) => sum + v);
    final average = values.isEmpty ? 0.0 : total / values.length;
    final window = _averageWindow(bucket, values.length);
    final averages = window < 2
        ? const <double?>[]
        : TrainingStatsCalculator.trailingAverage(values, window);
    // Przy samych zerach linia średniej leżałaby na osi pustego wykresu.
    final hasAverageLine =
        total > 0 && averages.whereType<double>().length >= 2;

    return SessionSectionCard(
      icon: Icons.bar_chart_rounded,
      title: 'Przebieg w czasie',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetricSwitch(
            selected: _metric,
            onChanged: (m) => setState(() => _metric = m),
          ),
          const SizedBox(height: AppSpacing.md),
          _Summary(
            total: _metric.format(total),
            caption: _metric.totalCaption(total),
            average: 'śr. ${_metric.format(average)} / ${_bucketNoun(bucket)}',
          ),
          const SizedBox(height: AppSpacing.md),
          if (series.isEmpty)
            const SizedBox.shrink()
          else
            _TrendChart(
              series: series,
              bucket: bucket,
              values: values,
              averages: hasAverageLine ? averages : const [],
              metric: _metric,
            ),
          const SizedBox(height: AppSpacing.sm),
          _Legend(
            color: _metric.color,
            currentLabel: _currentBucketLabel(bucket),
            averageLabel: hasAverageLine
                ? 'średnia krocząca · ${_averageWindowLabel(bucket, window)}'
                : null,
          ),
        ],
      ),
    );
  }
}

class _MetricSwitch extends StatelessWidget {
  const _MetricSwitch({required this.selected, required this.onChanged});

  final _TrendMetric selected;
  final ValueChanged<_TrendMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          for (final metric in _TrendMetric.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: metric == selected,
                label: 'Pokaż: ${metric.label}',
                excludeSemantics: true,
                // excludeSemantics usuwa akcję GestureDetectora — bez onTap
                // czytnik ekranu ogłasza przycisk, którego nie da się użyć.
                onTap: () => onChanged(metric),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (metric == selected) return;
                    HapticFeedback.selectionClick();
                    onChanged(metric);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: metric == selected
                          ? AppColors.surfaceVariant
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (metric == selected) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: metric.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(
                            metric.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: metric == selected
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: metric == selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

class _Summary extends StatelessWidget {
  const _Summary({
    required this.total,
    required this.caption,
    required this.average,
  });

  final String total;
  final String caption;
  final String average;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  total,
                  maxLines: 1,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            average,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({
    required this.series,
    required this.bucket,
    required this.values,
    required this.averages,
    required this.metric,
  });

  final List<StatsSeriesPoint> series;
  final StatsBucket bucket;
  final List<double> values;
  final List<double?> averages;
  final _TrendMetric metric;

  static const _height = 176.0;
  static const _leftReserved = 44.0;
  static const _bottomReserved = 24.0;
  static const _maxLabels = 6;

  @override
  Widget build(BuildContext context) {
    final count = values.length;
    final peak = [
      ...values,
      ...averages.whereType<double>(),
    ].fold<double>(0, math.max);
    final isEmpty = peak <= 0;
    final step = metric.gridStep(peak);
    // Góra osi zawsze na pełnej linii siatki.
    final maxY = isEmpty ? step * 4 : (peak / step).ceil() * step;
    // Podpisy co [stride] słupków, liczone od bieżącego — on zawsze ma
    // podpis, a ciasno upakowane dni się nie zlewają.
    final stride = (count / _maxLabels).ceil().clamp(1, count);

    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plotWidth = constraints.maxWidth - _leftReserved;
          final slot = plotWidth / count;
          final barWidth = (slot * 0.62).clamp(2.0, 22.0);
          final radius = Radius.circular(math.min(barWidth / 2, 5));

          final bars = BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: step,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.chartGrid,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: _leftReserved,
                    interval: step,
                    getTitlesWidget: (value, meta) {
                      if (value > maxY + 1e-6) return const SizedBox.shrink();
                      return SideTitleWidget(
                        meta: meta,
                        space: 6,
                        child: Text(
                          value == 0 ? '0' : metric.formatAxis(value),
                          style: _axisStyle,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: _bottomReserved,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if (i < 0 ||
                          i >= count ||
                          (count - 1 - i) % stride != 0) {
                        return const SizedBox.shrink();
                      }
                      final isCurrent = i == count - 1;
                      return SideTitleWidget(
                        meta: meta,
                        space: 6,
                        fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                        child: Text(
                          formatStatsBucketLabel(series[i].start, bucket),
                          style: _axisStyle.copyWith(
                            color: isCurrent
                                ? AppColors.textSecondary
                                : AppColors.textMuted,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                enabled: !isEmpty,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surfaceVariant,
                  tooltipBorder: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.9),
                  ),
                  tooltipBorderRadius: BorderRadius.circular(AppRadius.sm),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  tooltipMargin: 8,
                  maxContentWidth: 160,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final point = series[group.x];
                    return BarTooltipItem(
                      '${formatStatsBucketTitle(point.start, bucket)}\n',
                      const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text: metric.format(values[group.x]),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < count; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i],
                        width: barWidth,
                        color: i == count - 1
                            ? metric.color
                            : metric.color.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.only(
                          topLeft: radius,
                          topRight: radius,
                        ),
                        // Pusty wykres dostaje tory, żeby było widać siatkę
                        // przedziałów zamiast pustej planszy.
                        backDrawRodData: BackgroundBarChartRodData(
                          show: isEmpty,
                          toY: maxY,
                          color: AppColors.chartTrack,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            duration: const Duration(milliseconds: 250),
          );

          return Stack(
            children: [
              Positioned.fill(child: bars),
              if (averages.isNotEmpty)
                // Osobny wykres liniowy nad słupkami: x = i trafia w środek
                // słupka, bo spaceAround stawia środki w (i + ½) · szer. / n,
                // a oś X od -½ do n - ½ daje dokładnie to samo.
                Positioned(
                  left: _leftReserved,
                  right: 0,
                  top: 0,
                  bottom: _bottomReserved,
                  child: IgnorePointer(
                    child: LineChart(
                      LineChartData(
                        minX: -0.5,
                        maxX: count - 0.5,
                        minY: 0,
                        maxY: maxY,
                        titlesData: const FlTitlesData(show: false),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        lineTouchData: const LineTouchData(enabled: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < count; i++)
                                if (i < averages.length && averages[i] != null)
                                  FlSpot(i.toDouble(), averages[i]!),
                            ],
                            color: AppColors.statAmber,
                            barWidth: 2,
                            isCurved: true,
                            curveSmoothness: 0.2,
                            preventCurveOverShooting: true,
                            isStrokeCapRound: true,
                            dashArray: const [5, 4],
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                      duration: const Duration(milliseconds: 250),
                    ),
                  ),
                ),
              if (isEmpty)
                const Positioned(
                  left: _leftReserved,
                  right: 0,
                  top: 0,
                  bottom: _bottomReserved,
                  child: Center(
                    child: Text(
                      'Brak danych w tym okresie',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
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

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.currentLabel,
    this.averageLabel,
  });

  final Color color;
  final String currentLabel;
  final String? averageLabel;

  static const _style = TextStyle(
    color: AppColors.textMuted,
    fontSize: 11.5,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: 6,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(child: Text(currentLabel, style: _style)),
          ],
        ),
        if (averageLabel != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CustomPaint(
                size: Size(16, 9),
                painter: _DashPainter(AppColors.statAmber),
              ),
              const SizedBox(width: 6),
              Flexible(child: Text(averageLabel!, style: _style)),
            ],
          ),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    canvas
      ..drawLine(Offset(1, y), Offset(6, y), paint)
      ..drawLine(Offset(10, y), Offset(size.width - 1, y), paint);
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => oldDelegate.color != color;
}
