import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../training/presentation/widgets/stats/stats_format.dart';
import '../../domain/models/body_weight_entry.dart';
import '../../domain/services/body_weight_trend.dart';
import '../utils/profile_details_labels.dart';

/// Wykres ekranu „Masa ciała”: wygładzona linia trendu z wypełnieniem,
/// pojedyncze pomiary jako kropki, przerywana linia celu i dymek po dotyku.
/// Linia rysuje się od lewej (ClipRect odsłaniany kontrolerem), siatka
/// i podpisy stoją od początku. Oś X w dniach, więc przerwy są widoczne.
///
/// [entries] od najstarszego (co najmniej dwa), [trendKg] — wartości trendu
/// dla tych samych pomiarów.
class BodyWeightTrendChart extends StatefulWidget {
  const BodyWeightTrendChart({
    super.key,
    required this.entries,
    required this.trendKg,
    this.goalKg,
  }) : assert(entries.length >= 2, 'need at least two entries'),
       assert(entries.length == trendKg.length, 'one trend value per entry');

  final List<BodyWeightEntry> entries;
  final List<double> trendKg;
  final double? goalKg;

  @override
  State<BodyWeightTrendChart> createState() => _BodyWeightTrendChartState();
}

const _trendColor = AppColors.statTeal;
const _tooltipColor = Color(0xFF1E2638);
const _tooltipBorderColor = Color(0xFF2C3650);
const _touchLineColor = Color(0xFF55607A);

/// Miejsce na podpisy osi — takie samo w obu warstwach, żeby się pokrywały.
const _rightReserved = 26.0;
const _bottomReserved = 22.0;

class _BodyWeightTrendChartState extends State<BodyWeightTrendChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _reveal,
    curve: Curves.easeInOutCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _reveal.value = 1;
    } else if (_reveal.isDismissed) {
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final geometry = _ChartGeometry.of(
      widget.entries,
      widget.trendKg,
      widget.goalKg,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        LineChart(geometry.background(), duration: Duration.zero),
        ClipRect(
          clipper: _RevealClipper(_progress),
          child: LineChart(
            geometry.foreground(widget.entries, widget.trendKg),
            duration: Duration.zero,
          ),
        ),
      ],
    );
  }
}

/// Odsłania dziecko od lewej do [progress] jego szerokości.
class _RevealClipper extends CustomClipper<Rect> {
  _RevealClipper(this.progress) : super(reclip: progress);

  final Animation<double> progress;

  @override
  Rect getClip(Size size) =>
      // Pionowy zapas — dymek może wystawać ponad obszar wykresu.
      Rect.fromLTRB(-8, -64, size.width * progress.value + 8, size.height + 8);

  @override
  bool shouldReclip(_RevealClipper oldClipper) =>
      oldClipper.progress != progress;
}

/// Zakresy osi i podpisy wspólne dla tła (siatka, podpisy, cel) i warstwy
/// danych (trend, pomiary, dotyk).
class _ChartGeometry {
  _ChartGeometry({
    required this.first,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.yInterval,
    required this.goal,
  });

  factory _ChartGeometry.of(
    List<BodyWeightEntry> entries,
    List<double> trendKg,
    double? goalKg,
  ) {
    // Oś Y w jednostce, którą widzi użytkownik — podziałka wypada na
    // okrągłych liczbach także w funtach.
    final unit = WeightUnits.current;
    final values = [
      for (final e in entries) unit.fromKg(e.weightKg),
      for (final t in trendKg) unit.fromKg(t),
    ];
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    final span = hi - lo;
    // Cel tylko wtedy, gdy jest blisko danych — daleki spłaszczyłby linię.
    final goal = goalKg == null ? null : unit.fromKg(goalKg);
    final distance = goal == null
        ? 0.0
        : goal < lo
        ? lo - goal
        : math.max(goal - hi, 0.0);
    final showGoal = goal != null && distance <= math.max(span, 2.0);
    if (showGoal) {
      lo = math.min(lo, goal);
      hi = math.max(hi, goal);
    }
    final interval = _niceInterval((hi - lo) / 3);
    final minY = ((lo - interval * 0.4) / interval).floorToDouble() * interval;
    final maxY = ((hi + interval * 0.4) / interval).ceilToDouble() * interval;
    return _ChartGeometry(
      first: entries.first.date,
      maxX: math.max(
        bodyWeightDaysBetween(entries.first.date, entries.last.date).toDouble(),
        1,
      ),
      minY: minY,
      maxY: maxY,
      yInterval: interval,
      goal: showGoal ? goal : null,
    );
  }

  final DateTime first;
  final double maxX;
  final double minY;
  final double maxY;
  final double yInterval;

  /// Cel w jednostce osi; `null` — poza zakresem wykresu albo brak celu.
  final double? goal;

  /// 1, 2 albo 5 × 10^n — podziałka na okrągłych liczbach.
  static double _niceInterval(double raw) {
    if (raw <= 0) return 1;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    final normalized = raw / magnitude;
    final nice = normalized <= 1
        ? 1
        : normalized <= 2
        ? 2
        : normalized <= 5
        ? 5
        : 10;
    return math.max(nice * magnitude, 0.5);
  }

  double xOf(DateTime date) => bodyWeightDaysBetween(first, date).toDouble();

  DateTime dateAt(double x) =>
      DateTime(first.year, first.month, first.day + x.round());

  LineChartData _base({
    required bool labels,
    List<LineChartBarData> bars = const [],
    LineTouchData touch = const LineTouchData(enabled: false),
    FlGridData grid = const FlGridData(show: false),
    ExtraLinesData extraLines = const ExtraLinesData(),
  }) {
    return LineChartData(
      minX: 0,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      borderData: FlBorderData(show: false),
      gridData: grid,
      extraLinesData: extraLines,
      lineBarsData: bars,
      lineTouchData: touch,
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        leftTitles: const AxisTitles(),
        rightTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: _rightReserved,
            interval: yInterval,
            getTitlesWidget: (value, meta) {
              if (!labels || value == meta.max || value == meta.min) {
                return const SizedBox.shrink();
              }
              return SideTitleWidget(
                meta: meta,
                space: 4,
                child: Text(formatDisplayNumber(value), style: _axisStyle),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: _bottomReserved,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final label = labels ? _xLabel(value) : null;
              if (label == null) return const SizedBox.shrink();
              return SideTitleWidget(
                meta: meta,
                space: 6,
                fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                child: Text(label, style: _axisStyle),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Podpis osi X w dniu [value] albo `null`. Krótki okres — trzy daty,
  /// dłuższy — początki miesięcy (przy wielu latach z rokiem).
  String? _xLabel(double value) {
    if (value != value.roundToDouble()) return null;
    final date = dateAt(value);
    if (maxX <= 62) {
      final step = (maxX / 3).ceil();
      if (value.round() % step != 0) return null;
      return formatStatsDayMonth(date);
    }
    final months = (maxX / 30.4).ceil();
    final step = math.max(1, (months / 4).ceil());
    if (date.day != 1) {
      // Początek wykresu w połowie miesiąca — podpis, jeśli jest miejsce
      // przed następnym.
      final nextMonth = DateTime(date.year, date.month + 1);
      final roomy = bodyWeightDaysBetween(date, nextMonth) >= maxX * 0.15;
      if (value != 0 || step > 1 || !roomy) return null;
      return statsMonthsShort[date.month - 1];
    }
    if ((date.year * 12 + date.month) % step != 0) return null;
    final month = statsMonthsShort[date.month - 1];
    if (maxX <= 366) return month;
    return '$month ’${(date.year % 100).toString().padLeft(2, '0')}';
  }

  /// Siatka i podpisy osi — stoją od początku animacji.
  LineChartData background() {
    return _base(
      labels: true,
      grid: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: yInterval,
        checkToShowHorizontalLine: (value) => value != minY && value != maxY,
        getDrawingHorizontalLine: (_) => const FlLine(
          color: AppColors.chartGrid,
          strokeWidth: 1,
          dashArray: [3, 4],
        ),
      ),
    );
  }

  /// Trend z wypełnieniem, kropki pomiarów, linia celu i dotyk.
  LineChartData foreground(
    List<BodyWeightEntry> entries,
    List<double> trendKg,
  ) {
    final unit = WeightUnits.current;
    final goalValue = goal;
    final trendSpots = [
      for (var i = 0; i < entries.length; i++)
        FlSpot(xOf(entries[i].date), unit.fromKg(trendKg[i])),
    ];
    final rawSpots = [
      for (final e in entries) FlSpot(xOf(e.date), unit.fromKg(e.weightKg)),
    ];
    return _base(
      labels: false,
      extraLines: ExtraLinesData(
        // Pod linią trendu.
        extraLinesOnTop: false,
        horizontalLines: [
          if (goalValue != null)
            HorizontalLine(
              y: goalValue,
              color: AppColors.success.withValues(alpha: 0.7),
              strokeWidth: 1.5,
              dashArray: const [6, 5],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                padding: const EdgeInsets.only(left: 2, bottom: 4),
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
                labelResolver: (_) => 'cel ${formatDisplayNumber(goalValue)}',
              ),
            ),
        ],
      ),
      bars: [
        LineChartBarData(
          spots: trendSpots,
          color: _trendColor,
          barWidth: 3,
          isCurved: true,
          curveSmoothness: 0.35,
          preventCurveOverShooting: true,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _trendColor.withValues(alpha: 0.28),
                _trendColor.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        LineChartBarData(
          spots: rawSpots,
          color: Colors.transparent,
          barWidth: 0,
          dotData: FlDotData(
            getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
              radius: 2,
              color: _trendColor.withValues(alpha: 0.38),
              strokeWidth: 0,
            ),
          ),
        ),
      ],
      touch: LineTouchData(
        handleBuiltInTouches: true,
        getTouchedSpotIndicator: (bar, indexes) => [
          for (final _ in indexes)
            bar.barWidth == 0
                ? TouchedSpotIndicatorData(
                    const FlLine(color: Colors.transparent, strokeWidth: 0),
                    FlDotData(
                      getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                        radius: 4.5,
                        color: AppColors.textPrimary,
                        strokeColor: AppColors.surface,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : TouchedSpotIndicatorData(
                    const FlLine(
                      color: _touchLineColor,
                      strokeWidth: 1,
                      dashArray: [2, 3],
                    ),
                    FlDotData(
                      getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                        radius: 4,
                        color: _trendColor,
                        strokeColor: AppColors.surface,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
        ],
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => _tooltipColor,
          tooltipBorder: const BorderSide(color: _tooltipBorderColor),
          tooltipBorderRadius: BorderRadius.circular(12),
          tooltipPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          tooltipHorizontalAlignment: FLHorizontalAlignment.left,
          tooltipHorizontalOffset: -12,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItems: (touched) => [
            for (final t in touched)
              t.barIndex == 1
                  ? _tooltip(entries[t.spotIndex], trendKg[t.spotIndex])
                  : null,
          ],
        ),
      ),
    );
  }

  LineTooltipItem _tooltip(BodyWeightEntry entry, double trend) {
    final weekday = statsWeekdaysShort[entry.date.weekday - 1].toLowerCase();
    return LineTooltipItem(
      '$weekday ${formatStatsDayMonth(entry.date)}\n',
      const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      textAlign: TextAlign.left,
      children: [
        TextSpan(
          text: '${formatWeightKg(entry.weightKg)}\n',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        TextSpan(
          text: 'trend ${formatWeightNumber(trend)}',
          style: const TextStyle(
            color: _trendColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

const _axisStyle = TextStyle(
  color: AppColors.textMuted,
  fontSize: 10.5,
  fontWeight: FontWeight.w700,
  fontFeatures: [FontFeature.tabularFigures()],
);
