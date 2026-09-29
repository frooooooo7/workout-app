import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../domain/models/training_stats.dart';
import '../session_details/session_section_card.dart';
import 'stats_format.dart';

/// Cel tygodniowy z profilu: postęp bieżącego tygodnia, historia ostatnich
/// tygodni i seria wykonanych celów.
class StatsGoalCard extends StatelessWidget {
  const StatsGoalCard({super.key, required this.goal});

  final WeeklyGoalProgress goal;

  @override
  Widget build(BuildContext context) {
    return SessionSectionCard(
      icon: Icons.track_changes_rounded,
      title: 'Cel tygodnia',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GoalHero(goal: goal),
          if (goal.weeks.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _GoalHistory(goal: goal),
          ],
          const SizedBox(height: AppSpacing.md),
          _StreakRow(goal: goal),
        ],
      ),
    );
  }
}

/// „3 / 4”, status tygodnia i pierścień postępu.
class _GoalHero extends StatelessWidget {
  const _GoalHero({required this.goal});

  final WeeklyGoalProgress goal;

  @override
  Widget build(BuildContext context) {
    final g = goal;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Treningi w tym tygodniu',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Semantics(
                container: true,
                label: '${g.workoutsThisWeek} z ${g.goal} treningów',
                excludeSemantics: true,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${g.workoutsThisWeek}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      TextSpan(
                        text: ' / ${g.goal}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    height: 1.15,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _GoalStatus(goal: g),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        _GoalRing(goal: g),
      ],
    );
  }
}

class _GoalStatus extends StatelessWidget {
  const _GoalStatus({required this.goal});

  final WeeklyGoalProgress goal;

  @override
  Widget build(BuildContext context) {
    final g = goal;
    if (g.met) {
      return const Text(
        'Cel wykonany',
        style: TextStyle(
          color: AppColors.success,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final remaining = g.remaining;
    final missing =
        'Brakuje $remaining '
        '${polishPlural(remaining, 'treningu', 'treningów', 'treningów')}';
    // `daysLeft` nie liczy dzisiejszego dnia, a dziś jeszcze można trenować.
    final String detail;
    if (!g.reachable) {
      detail = 'Cel w tym tygodniu jest już poza zasięgiem';
    } else if (g.daysLeft == 0) {
      detail = 'dziś ostatni dzień';
    } else {
      detail = 'do końca tygodnia: ${g.daysLeft + 1} dni';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          missing,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// Pierścień postępu; w środku procent albo ptaszek po wykonaniu celu.
class _GoalRing extends StatelessWidget {
  const _GoalRing({required this.goal});

  final WeeklyGoalProgress goal;

  static const _size = 76.0;
  static const _stroke = 8.0;

  @override
  Widget build(BuildContext context) {
    final g = goal;
    final fraction = (g.workoutsThisWeek / g.goal).clamp(0.0, 1.0);
    // Niewykonany cel nigdy nie pokazuje „100%”.
    final percent = g.met ? 100 : math.min(99, (fraction * 100).round());
    final color = g.met ? AppColors.success : AppColors.primaryVariant;

    return ExcludeSemantics(
      child: SizedBox(
        width: _size,
        height: _size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: fraction),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => CustomPaint(
            painter: _RingPainter(
              fraction: value,
              color: color,
              track: AppColors.surfaceVariant,
              stroke: _stroke,
            ),
            child: child,
          ),
          child: Center(
            child: g.met
                ? const Icon(
                    Icons.check_rounded,
                    size: 32,
                    color: AppColors.success,
                  )
                : Text(
                    '$percent%',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double fraction;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arc, 0, math.pi * 2, false, paint..color = track);
    if (fraction <= 0) return;
    canvas.drawArc(
      arc,
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}

/// Słupki ostatnich tygodni z przerywaną linią celu.
class _GoalHistory extends StatelessWidget {
  const _GoalHistory({required this.goal});

  final WeeklyGoalProgress goal;

  @override
  Widget build(BuildContext context) {
    final g = goal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Ostatnie tygodnie',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'cel: ${g.goal} / tydz.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _GoalBars(goal: g),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Wykonany w ${g.weeksMet} z ${g.weeks.length} ostatnich tygodni',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _GoalBars extends StatelessWidget {
  const _GoalBars({required this.goal});

  final WeeklyGoalProgress goal;

  /// Wysokość najwyższego słupka.
  static const _barArea = 64.0;
  static const _padV = 6.0;
  static const _gap = 6.0;
  static const _valueFont = 11.0;
  static const _labelFont = 10.5;

  @override
  Widget build(BuildContext context) {
    final g = goal;
    final weeks = g.weeks;
    final scaler = MediaQuery.textScalerOf(context);
    // Podpisy mają stałą wysokość zależną od skali tekstu, żeby linia celu
    // trafiała dokładnie w skalę słupków.
    final valueHeight = scaler.scale(_valueFont);
    final labelHeight = scaler.scale(_labelFont);

    final tallest = weeks.fold<int>(0, (m, w) => math.max(m, w.workouts));
    // Cel leży na ⅔ wysokości; tydzień powyżej 1,5 × cel wydłuża skalę.
    final ceiling = math.max(g.goal * 1.5, tallest.toDouble());
    final plotTop = _padV + valueHeight + 3;
    final total = plotTop + _barArea + _gap + labelHeight + _padV;
    final last = weeks.length - 1;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: [
        'Treningi w ostatnich tygodniach, cel ${g.goal}',
        for (final w in weeks)
          '${formatStatsBucketTitle(w.start, StatsBucket.week)}: ${w.workouts}',
      ].join(', '),
      child: SizedBox(
        height: total,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: plotTop,
              height: _barArea,
              child: CustomPaint(
                painter: _GoalLinePainter(
                  fraction: (g.goal / ceiling).clamp(0.0, 1.0),
                  color: AppColors.textSecondary.withValues(alpha: 0.55),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < weeks.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: _GoalBarColumn(
                        week: weeks[i],
                        goal: g.goal,
                        ceiling: ceiling,
                        isCurrent: i == last,
                        // Co drugi podpis, licząc od bieżącego tygodnia.
                        showLabel: (last - i) % 2 == 0,
                        valueHeight: valueHeight,
                        labelHeight: labelHeight,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalBarColumn extends StatelessWidget {
  const _GoalBarColumn({
    required this.week,
    required this.goal,
    required this.ceiling,
    required this.isCurrent,
    required this.showLabel,
    required this.valueHeight,
    required this.labelHeight,
  });

  final GoalWeek week;
  final int goal;
  final double ceiling;
  final bool isCurrent;
  final bool showLabel;
  final double valueHeight;
  final double labelHeight;

  @override
  Widget build(BuildContext context) {
    final count = week.workouts;
    final met = count >= goal;
    final barHeight = count == 0
        ? 3.0
        : math.max(
            4.0,
            _GoalBars._barArea * math.min(count.toDouble(), ceiling) / ceiling,
          );
    final color = count == 0
        ? AppColors.surfaceVariant
        : met
        ? (isCurrent
              ? AppColors.success
              : AppColors.success.withValues(alpha: 0.6))
        : (isCurrent
              ? AppColors.primaryVariant
              : AppColors.primary.withValues(alpha: 0.45));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.primary.withValues(alpha: 0.08) : null,
        border: isCurrent
            ? Border.all(color: AppColors.primaryVariant.withValues(alpha: 0.5))
            : null,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _GoalBars._padV),
        child: Column(
          children: [
            SizedBox(
              height: valueHeight,
              child: Center(
                child: Text(
                  count == 0 ? '' : '$count',
                  maxLines: 1,
                  style: TextStyle(
                    color: isCurrent
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontSize: _GoalBars._valueFont,
                    height: 1,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: _GoalBars._barArea,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  widthFactor: 0.6,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: barHeight),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    builder: (context, h, _) => Container(
                      height: h,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: _GoalBars._gap),
            SizedBox(
              height: labelHeight,
              child: showLabel
                  ? LayoutBuilder(
                      builder: (context, c) => OverflowBox(
                        // Podpis może wyjść poza własną kolumnę — sąsiednia
                        // nie ma podpisu.
                        minWidth: 0,
                        maxWidth: c.maxWidth * 2,
                        child: Text(
                          formatStatsDayMonth(week.start),
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: isCurrent
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            fontSize: _GoalBars._labelFont,
                            height: 1,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalLinePainter extends CustomPainter {
  const _GoalLinePainter({required this.fraction, required this.color});

  /// Wysokość linii celu jako ułamek obszaru słupków.
  final double fraction;
  final Color color;

  static const _dash = 4.0;
  static const _space = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * (1 - fraction);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += _dash + _space) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + _dash, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GoalLinePainter old) =>
      old.fraction != fraction || old.color != color;
}

class _StreakRow extends StatelessWidget {
  const _StreakRow({required this.goal});

  final WeeklyGoalProgress goal;

  @override
  Widget build(BuildContext context) {
    final g = goal;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            Icons.flag_rounded,
            size: 18,
            color: g.streakWeeks > 0 ? AppColors.trendUp : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: 2,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Seria celu: ',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: '${g.streakWeeks} tyg.',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'najdłuższa: ${g.bestStreakWeeks} tyg.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
