import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/utils/polish_plural.dart';
import '../../../../domain/models/training_stats.dart';
import '../stats_format.dart';
import 'stats_headlines.dart';
import 'stats_overview_card.dart';

/// Górna karta pulpitu: ile treningów w okresie, słupki tygodni na tle celu
/// i trzy liczby pod spodem (objętość, czas, serie). „Przebieg w czasie”
/// otwiera wykres z wyborem miary.
class StatsPeriodSummaryCard extends StatelessWidget {
  const StatsPeriodSummaryCard({
    super.key,
    required this.snapshot,
    required this.onOpenTrend,
  });

  final TrainingStatsSnapshot snapshot;
  final VoidCallback onOpenTrend;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final current = s.current;
    final previous = s.previous;
    final workouts = current.workouts;
    final bars = _bars(s);
    final goalWeeks = _goalWeeks(s);
    final inactivity = s.insights
        .where((i) => i.kind == StatsInsightKind.inactivity)
        .firstOrNull;
    final countDelta = previous == null
        ? null
        : StatsDelta.absolute(workouts, previous.workouts);

    final volume = formatStatsVolume(current.volumeKg);
    final duration = formatStatsDuration(current.durationSec);

    return StatsOverviewCard(
      title: StatsHeadlines.periodTitle(s),
      trailing: previous == null || s.range.previousLabel.isEmpty
          ? null
          : Text(
              'vs ${s.range.previousLabel}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$workouts',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 52,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      polishPlural(
                        workouts,
                        'trening',
                        'treningi',
                        'treningów',
                      ),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (countDelta != null) _Delta(delta: countDelta),
                  ],
                ),
              ),
              if (goalWeeks != null)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _GoalPill(met: goalWeeks.met, of: goalWeeks.total),
                  ),
                ),
            ],
          ),
          if (inactivity != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: AppColors.statAmber,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    inactivity.text,
                    style: const TextStyle(
                      color: AppColors.statAmber,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (bars != null) ...[
            const SizedBox(height: 16),
            _WeekBars(bars: bars),
          ],
          const SizedBox(height: 14),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MiniStat(
                  value: volume.value,
                  unit: volume.unit,
                  label: 'objętość',
                  delta: previous == null
                      ? null
                      : StatsDelta.percent(current.volumeKg, previous.volumeKg),
                ),
              ),
              Expanded(
                child: _MiniStat(
                  value: duration.value,
                  unit: duration.unit,
                  label: 'na treningach',
                  delta: previous == null
                      ? null
                      : StatsDelta.percent(
                          current.durationSec,
                          previous.durationSec,
                        ),
                ),
              ),
              Expanded(
                child: _MiniStat(
                  value: formatStatsDecimal(current.completedSets.toDouble()),
                  unit: '',
                  label: 'serii',
                  delta: previous == null
                      ? null
                      : StatsDelta.percent(
                          current.completedSets,
                          previous.completedSets,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.border.withValues(alpha: 0.7),
          ),
          Semantics(
            button: true,
            child: InkWell(
              key: const ValueKey('stats-open-trend'),
              onTap: onOpenTrend,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Przebieg w czasie',
                      style: TextStyle(
                        color: AppColors.primaryVariant,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.primaryVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tygodnie z oknem zakresu, w których cel był do wykonania: bez
  /// bieżącego, jeśli jeszcze trwa i cel nie jest wykonany.
  static ({int met, int total})? _goalWeeks(TrainingStatsSnapshot s) {
    final goal = s.goal;
    if (goal == null) return null;
    final weeks = _weeksInWindow(s, goal);
    var met = 0;
    var total = 0;
    for (var i = 0; i < weeks.length; i++) {
      final isCurrent = weeks[i].start == goal.weeks.last.start;
      final done = weeks[i].workouts >= goal.goal;
      if (isCurrent && !done) continue;
      total++;
      if (done) met++;
    }
    return total == 0 ? null : (met: met, total: total);
  }

  static List<GoalWeek> _weeksInWindow(
    TrainingStatsSnapshot s,
    WeeklyGoalProgress goal,
  ) => [
    for (final w in goal.allWeeks)
      if (w.start.add(const Duration(days: 7)).isAfter(s.window.start) &&
          w.start.isBefore(s.window.end))
        w,
  ];

  static const _maxBars = 52;

  /// Słupki: tygodnie na tle celu, a bez celu kolejne przedziały wykresu.
  static _Bars? _bars(TrainingStatsSnapshot s) {
    final goal = s.goal;
    if (goal != null) {
      final weeks = _weeksInWindow(s, goal);
      if (weeks.isNotEmpty) {
        // Przy „Całość” tygodni bywa setki — słupki pokazują ostatni rok,
        // a licznik „cel w X z Y tyg.” liczy cały zakres.
        final shown = weeks.length > _maxBars
            ? weeks.sublist(weeks.length - _maxBars)
            : weeks;
        return _Bars([
          for (final w in shown)
            _Bar(
              value: w.workouts,
              label: formatStatsDayMonth(w.start),
              current: w.start == goal.weeks.last.start,
            ),
        ], goal: goal.goal);
      }
    }
    if (s.series.isEmpty || s.series.every((p) => p.workouts == 0)) return null;
    final bucket = s.window.bucket;
    final last = s.series.length - 1;
    return _Bars([
      for (var i = 0; i < s.series.length; i++)
        _Bar(
          value: s.series[i].workouts,
          label: formatStatsBucketLabel(s.series[i].start, bucket),
          current: i == last,
        ),
    ]);
  }
}

class _Bar {
  const _Bar({required this.value, required this.label, required this.current});

  final int value;
  final String label;
  final bool current;
}

class _Bars {
  const _Bars(this.bars, {this.goal});

  final List<_Bar> bars;
  final int? goal;
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.bars});

  final _Bars bars;

  static const _plot = 70.0;

  @override
  Widget build(BuildContext context) {
    final items = bars.bars;
    final goal = bars.goal;
    final maxValue = math.max(
      items.fold<int>(0, (m, b) => math.max(m, b.value)),
      goal ?? 1,
    );
    final dense = items.length > 8;
    final labelEvery = items.length <= 6 ? 1 : (items.length / 3).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _plot + 20,
          child: Stack(
            children: [
              if (goal != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: _plot * goal / maxValue,
                  child: const SizedBox(
                    height: 1,
                    child: CustomPaint(painter: _DashPainter()),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: items.length > 30
                              ? 0.5
                              : (dense ? 1.5 : 3),
                        ),
                        child: _BarColumn(
                          bar: items[i],
                          goal: goal,
                          maxValue: maxValue,
                          showValue: !dense,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Text(
                  i % labelEvery == 0 || i == items.length - 1
                      ? items[i].label
                      : '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        if (goal != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              const _LegendDot(color: AppColors.success, label: 'cel wykonany'),
              _LegendDot(
                color: AppColors.primary.withValues(alpha: 0.4),
                label: 'poniżej celu',
              ),
              Text(
                '- -  cel: $goal / tydz.',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.bar,
    required this.goal,
    required this.maxValue,
    required this.showValue,
  });

  final _Bar bar;
  final int? goal;
  final int maxValue;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final met = goal != null && bar.value >= goal!;
    final color = goal == null
        ? AppColors.primaryVariant
        : met
        ? AppColors.success
        : AppColors.primary.withValues(alpha: 0.4);
    final height = bar.value == 0
        ? 4.0
        : math.max(6.0, _WeekBars._plot * bar.value / maxValue);
    return Container(
      decoration: bar.current
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primaryVariant.withValues(alpha: 0.8),
              ),
              color: AppColors.primary.withValues(alpha: 0.08),
            )
          : null,
      padding: bar.current
          ? const EdgeInsets.fromLTRB(2, 2, 2, 2)
          : EdgeInsets.zero,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (showValue)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '${bar.value}',
                style: TextStyle(
                  color: bar.current
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + 4, size.width), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
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

class _GoalPill extends StatelessWidget {
  const _GoalPill({required this.met, required this.of});

  final int met;
  final int of;

  @override
  Widget build(BuildContext context) {
    final all = met == of;
    final color = all ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            all ? Icons.check_circle_rounded : Icons.flag_outlined,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            'cel w $met z $of tyg.',
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.value,
    required this.unit,
    required this.label,
    required this.delta,
  });

  final String value;
  final String unit;
  final String label;
  final StatsDelta? delta;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label:
          '$label ${'$value $unit'.trim()}'
          '${delta == null ? '' : ', zmiana ${delta!.text}'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 16,
            child: delta == null ? null : _Delta(delta: delta!, compact: true),
          ),
        ],
      ),
    );
  }
}

class _Delta extends StatelessWidget {
  const _Delta({required this.delta, this.compact = false});

  final StatsDelta delta;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (delta.direction) {
      > 0 => AppColors.trendUp,
      < 0 => AppColors.trendDown,
      _ => AppColors.textMuted,
    };
    final icon = switch (delta.direction) {
      > 0 => Icons.arrow_upward_rounded,
      < 0 => Icons.arrow_downward_rounded,
      _ => Icons.remove_rounded,
    };
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 13 : 15, color: color),
          const SizedBox(width: 2),
          Text(
            // Strzałka niesie kierunek, więc znak z tekstu zbędny.
            delta.text.replaceFirst(RegExp('^[+−]'), ''),
            style: TextStyle(
              color: color,
              fontSize: compact ? 12 : 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
