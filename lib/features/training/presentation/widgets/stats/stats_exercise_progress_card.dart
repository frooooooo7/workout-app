import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/units/weight_unit.dart';
import '../../../domain/models/training_stats.dart';
import '../session_details/session_section_card.dart';
import 'stats_format.dart';

enum _Metric {
  oneRepMax('1RM'),
  weight('Ciężar'),
  volume('Objętość'),
  reps('Powtórzenia');

  const _Metric(this.label);

  final String label;

  /// Wartość punktu w jednostce osi — ciężary w aktualnej jednostce.
  double? valueOf(ExerciseProgressPoint p) {
    final unit = WeightUnits.current;
    final v = switch (this) {
      _Metric.oneRepMax => switch (p.oneRepMaxKg) {
        final kg? => unit.fromKg(kg),
        null => null,
      },
      _Metric.weight => switch (p.topWeightKg) {
        final kg? => unit.fromKg(kg),
        null => null,
      },
      _Metric.volume => unit.fromKg(p.volumeKg),
      _Metric.reps => p.maxReps?.toDouble(),
    };
    return v == null || v <= 0 ? null : v;
  }

  /// Pełna wartość z jednostką; [v] w jednostce osi (patrz [valueOf]).
  String format(double v) => switch (this) {
    _Metric.volume => _joinUnit(formatStatsVolume(WeightUnits.current.toKg(v))),
    _Metric.reps => '${v.round()} powt.',
    _Metric.oneRepMax =>
      '${formatStatsDecimal(v, digits: 0)} ${WeightUnits.current.label}',
    _Metric.weight => '${formatStatsDecimal(v)} ${WeightUnits.current.label}',
  };

  /// Zmiana ze znakiem: `+5 kg`, `−2 powt.`
  String formatChange(double diff) {
    final sign = diff > 0 ? '+' : (diff < 0 ? '−' : '±');
    return '$sign${format(diff.abs())}';
  }

  /// Krótka etykieta osi Y.
  String axis(double v) => switch (this) {
    _Metric.volume =>
      v >= 10000
          ? (WeightUnits.current == WeightUnit.lb
                ? '${formatStatsDecimal(v / 1000)}k'
                : '${formatStatsDecimal(v / 1000)} t')
          : formatStatsDecimal(v, digits: 0),
    _ => formatStatsDecimal(v, digits: v.abs() < 10 ? 1 : 0),
  };
}

String _joinUnit(StatsValue v) => '${v.value} ${v.unit}';

/// Wykres progresu wybranego ćwiczenia: najlepsza seria z każdego treningu
/// od [progressFrom].
class StatsExerciseProgressCard extends StatefulWidget {
  const StatsExerciseProgressCard({
    super.key,
    required this.exercises,
    required this.progressFrom,
  });

  final List<ExerciseProgress> exercises;
  final DateTime progressFrom;

  @override
  State<StatsExerciseProgressCard> createState() =>
      _StatsExerciseProgressCardState();
}

class _StatsExerciseProgressCardState extends State<StatsExerciseProgressCard> {
  String? _selectedKey;
  _Metric _metric = _Metric.oneRepMax;

  ExerciseProgress? get _selected {
    final list = widget.exercises;
    if (list.isEmpty) return null;
    return list.firstWhere(
      (e) => e.exerciseKey == _selectedKey,
      orElse: () => list.first,
    );
  }

  static List<_Metric> _metricsFor(ExerciseProgress e) => e.hasWeights
      ? const [_Metric.oneRepMax, _Metric.weight, _Metric.volume]
      : const [_Metric.reps];

  void _select(ExerciseProgress e) {
    setState(() {
      _selectedKey = e.exerciseKey;
      final metrics = _metricsFor(e);
      if (!metrics.contains(_metric)) _metric = metrics.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return SessionSectionCard(
      icon: Icons.show_chart_rounded,
      title: 'Progres ćwiczeń',
      child: selected == null
          ? const Text(
              'Brak ćwiczeń w tym okresie — progres pojawi się po treningu.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            )
          : _buildContent(selected),
    );
  }

  Widget _buildContent(ExerciseProgress exercise) {
    final metrics = _metricsFor(exercise);
    final metric = metrics.contains(_metric) ? _metric : metrics.first;
    final spots = <({DateTime date, double value})>[
      for (final p in exercise.points)
        if (metric.valueOf(p) case final v?) (date: p.date.toLocal(), value: v),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ExercisePicker(
          exercises: widget.exercises,
          selectedKey: exercise.exerciseKey,
          onSelect: _select,
        ),
        const SizedBox(height: AppSpacing.sm),
        _MetricToggle(
          metrics: metrics,
          selected: metric,
          onSelect: (m) => setState(() => _metric = m),
        ),
        const SizedBox(height: AppSpacing.md),
        if (spots.length < 2)
          _TooFewPoints(
            lastValue: spots.isEmpty ? null : metric.format(spots.last.value),
          )
        else ...[
          _HeaderStats(
            metric: metric,
            values: [for (final s in spots) s.value],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 180,
            child: _ProgressChart(metric: metric, spots: spots),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Najlepsza seria z każdego treningu od '
          '${formatStatsLongDate(widget.progressFrom)}',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ExercisePicker extends StatelessWidget {
  const _ExercisePicker({
    required this.exercises,
    required this.selectedKey,
    required this.onSelect,
  });

  final List<ExerciseProgress> exercises;
  final String selectedKey;
  final ValueChanged<ExerciseProgress> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: exercises.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final e = exercises[i];
          final isSelected = e.exerciseKey == selectedKey;
          return Semantics(
            button: true,
            selected: isSelected,
            child: InkWell(
              onTap: () => onSelect(e),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                constraints: const BoxConstraints(maxWidth: 170),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.18)
                      : AppColors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryVariant.withValues(alpha: 0.7)
                        : AppColors.border.withValues(alpha: 0.7),
                  ),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    e.exerciseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetricToggle extends StatelessWidget {
  const _MetricToggle({
    required this.metrics,
    required this.selected,
    required this.onSelect,
  });

  final List<_Metric> metrics;
  final _Metric selected;
  final ValueChanged<_Metric> onSelect;

  @override
  Widget build(BuildContext context) {
    // Przy dużej czcionce systemowej trzy pigułki nie mieszczą się w wierszu
    // — zmniejszamy je zamiast przepełniać.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.chartTrack,
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final m in metrics)
                Semantics(
                  button: true,
                  selected: m == selected,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: m == selected
                            ? AppColors.surfaceVariant
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        m.label,
                        style: TextStyle(
                          color: m == selected
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStats extends StatelessWidget {
  const _HeaderStats({required this.metric, required this.values});

  final _Metric metric;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final last = values.last;
    final best = values.reduce(math.max);
    final diff = last - values.first;
    // Poniżej pół jednostki to szum z zaokrągleń — „bez zmian”.
    final flat = diff.abs() < 0.5;
    final color = flat
        ? AppColors.textSecondary
        : (diff > 0 ? AppColors.trendUp : AppColors.trendDown);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Stat(label: 'Ostatnio', value: metric.format(last)),
        ),
        Expanded(
          child: _Stat(label: 'Najlepszy', value: metric.format(best)),
        ),
        Expanded(
          child: _Stat(
            label: 'Zmiana',
            value: flat ? 'bez zmian' : metric.formatChange(diff),
            color: color,
            icon: flat
                ? null
                : (diff > 0
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.color = AppColors.textPrimary,
    this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 2),
              ],
              Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TooFewPoints extends StatelessWidget {
  const _TooFewPoints({required this.lastValue});

  final String? lastValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.chartTrack,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          if (lastValue != null) ...[
            Text(
              lastValue!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
          ],
          const Text(
            'Za mało treningów, żeby narysować progres',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressChart extends StatelessWidget {
  const _ProgressChart({required this.metric, required this.spots});

  final _Metric metric;
  final List<({DateTime date, double value})> spots;

  static const _dayMs = 86400000;

  @override
  Widget build(BuildContext context) {
    final first = spots.first.date;
    final spanDays = spots.last.date.difference(first).inMilliseconds / _dayMs;
    // Oś czasu w dniach; gdy wszystkie punkty są z jednego dnia, po kolei.
    final byTime = spanDays >= 1;
    double xOf(int i) => byTime
        ? spots[i].date.difference(first).inMilliseconds / _dayMs
        : i.toDouble();
    final flSpots = [
      for (var i = 0; i < spots.length; i++) FlSpot(xOf(i), spots[i].value),
    ];
    final maxX = flSpots.last.x;

    final values = [for (final s in spots) s.value];
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final pad = math.max((hi - lo) * 0.2, math.max(hi * 0.05, 1.0));
    final minY = math.max(0.0, lo - pad);
    final maxY = hi + pad;
    final yInterval = (maxY - minY) / 3;

    String dateAt(double x) {
      if (!byTime) {
        final i = x.round().clamp(0, spots.length - 1);
        return formatStatsDayMonth(spots[i].date);
      }
      return formatStatsDayMonth(
        first.add(Duration(milliseconds: (x * _dayMs).round())),
      );
    }

    final lastIndex = flSpots.length - 1;
    final showAllDots = flSpots.length <= 24;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.horizontal(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: yInterval > 0 ? yInterval : null,
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
              reservedSize: 40,
              interval: yInterval > 0 ? yInterval : null,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(metric.axis(value), style: _axisStyle),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              // Co najmniej dzień między podpisami — inaczej krótki zakres
              // powtarzałby tę samą datę kilka razy.
              interval: byTime ? math.max(maxX / 3, 1) : 1,
              getTitlesWidget: (value, meta) {
                // Punkty z jednego dnia mają jedną datę — wystarczy podpis
                // pod pierwszym.
                if (!byTime && value > 0) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(dateAt(value), style: _axisStyle),
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
                  color: AppColors.primaryVariant.withValues(alpha: 0.4),
                  strokeWidth: 1,
                  dashArray: const [3, 3],
                ),
                FlDotData(
                  getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                    radius: 5,
                    color: AppColors.primaryVariant,
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
                  '${formatStatsDayMonth(spots[t.spotIndex].date)}\n',
                  const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(
                      text: metric.format(spots[t.spotIndex].value),
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
            spots: flSpots,
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            color: AppColors.primaryVariant,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              checkToShowDot: (spot, bar) =>
                  showAllDots || bar.spots.indexOf(spot) == lastIndex,
              getDotPainter: (spot, _, bar, index) => index == lastIndex
                  ? FlDotCirclePainter(
                      radius: 5,
                      color: AppColors.primaryVariant,
                      strokeColor: AppColors.textPrimary,
                      strokeWidth: 2,
                    )
                  : FlDotCirclePainter(
                      radius: 2.8,
                      color: AppColors.primaryVariant,
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
                  AppColors.primaryVariant.withValues(alpha: 0.28),
                  AppColors.primaryVariant.withValues(alpha: 0),
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
