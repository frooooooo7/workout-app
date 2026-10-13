import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/plan_colors.dart';
import '../../../../core/utils/polish_plural.dart';
import '../../domain/models/training_stats.dart';
import 'training_day_status.dart';

/// Stan dnia w pasku tygodnia.
enum WeekDayState {
  /// Ukończony trening — kółko wypełnione kolorem planu.
  done,

  /// Dziś, jeszcze bez treningu — pierścień z pulsem.
  today,

  /// Zaplanowany (także miniony, ale opuszczony) — kropka w kolorze planu.
  planned,

  /// Wolne — przerywany okrąg.
  rest,
}

/// Karta „Ten tydzień”: licznik treningów względem celu, seria tygodni
/// i siedem dni ze stanem (zrobione / dziś / zaplanowane / wolne).
/// Stuknięcie dnia pokazuje jego plan w karcie poniżej.
class TrainingWeekStrip extends StatelessWidget {
  const TrainingWeekStrip({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
    this.scheduledPlans = const {},
    this.donePlans = const {},
    this.weeklyGoal,
    this.today,
  });

  /// 1 = poniedziałek … 7 = niedziela.
  final int selectedDay;
  final ValueChanged<int> onDaySelected;

  /// Dzień tygodnia → nazwa planu zaplanowanego na ten dzień.
  final Map<int, String> scheduledPlans;

  /// Dzień tygodnia → nazwa planu ukończonego tego dnia treningu.
  final Map<int, String> donePlans;

  /// Cel z profilu; bez niego mianownikiem są dni zaplanowane w planach.
  final WeeklyGoalProgress? weeklyGoal;

  /// Test seam; domyślnie [DateTime.now].
  final DateTime? today;

  static const _letters = ['P', 'W', 'Ś', 'C', 'P', 'S', 'N'];

  @override
  Widget build(BuildContext context) {
    final now = today ?? DateTime.now();
    final weekStart = startOfWeekContaining(now);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _WeekSummary(
              // Cel liczy treningi, nie dni — dwa treningi jednego dnia to dwa.
              done: weeklyGoal?.workoutsThisWeek ?? donePlans.length,
              target: weeklyGoal?.goal ?? scheduledPlans.length,
              streakWeeks: weeklyGoal?.streakWeeks ?? 0,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: _buildDay(
                    // Konstruktor, nie `add(Duration)` — doba przy zmianie
                    // czasu nie ma 24 h.
                    DateTime(
                      weekStart.year,
                      weekStart.month,
                      weekStart.day + i,
                    ),
                    now,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDay(DateTime date, DateTime now) {
    final weekday = date.weekday;
    final isToday = calendarDateOnly(date) == calendarDateOnly(now);
    final donePlan = donePlans[weekday];
    final plannedPlan = scheduledPlans[weekday];
    final state = donePlan != null
        ? WeekDayState.done
        : isToday
        ? WeekDayState.today
        : plannedPlan != null
        ? WeekDayState.planned
        : WeekDayState.rest;
    final planName = donePlan ?? plannedPlan;
    final isFuture = isCalendarDateAfter(date, now);

    final String caption;
    if (isToday) {
      caption = 'dziś';
    } else if (isFuture) {
      caption = plannedPlan ?? 'wolne';
    } else if (donePlan != null) {
      // Zrobiony dzień ma w kółku ptaszek, więc pod spodem zostaje data.
      caption = '${date.day}';
    } else {
      caption = plannedPlan != null ? 'brak' : 'wolne';
    }

    return _WeekDay(
      key: ValueKey('week-day-$weekday'),
      letter: _letters[weekday - 1],
      dayNumber: date.day,
      caption: caption,
      state: state,
      color: planName == null
          ? AppColors.primaryVariant
          : PlanColors.of(planName),
      isToday: isToday,
      isSelected: weekday == selectedDay && !isToday,
      semanticLabel: _semanticLabel(date, state, planName, isToday),
      onTap: () => onDaySelected(weekday),
    );
  }

  static String _semanticLabel(
    DateTime date,
    WeekDayState state,
    String? plan,
    bool isToday,
  ) {
    final day = '${kTrainingWeekdayFullNames[date.weekday - 1]} ${date.day}';
    final status = switch (state) {
      WeekDayState.done => '$plan zrobiony',
      WeekDayState.today => plan == null ? 'dziś wolne' : 'dziś $plan',
      WeekDayState.planned => 'zaplanowany $plan',
      WeekDayState.rest => 'wolne',
    };
    return isToday && state == WeekDayState.done
        ? '$day, dziś $status'
        : '$day, $status';
  }
}

/// „Ten tydzień · 3 z 4 treningów · 🔥 11 tyg.”
class _WeekSummary extends StatelessWidget {
  const _WeekSummary({
    required this.done,
    required this.target,
    required this.streakWeeks,
  });

  final int done;
  final int target;
  final int streakWeeks;

  @override
  Widget build(BuildContext context) {
    final rest = target > 0
        ? ' z $target ${target == 1 ? 'treningu' : 'treningów'}'
        : ' ${polishPlural(done, 'trening', 'treningi', 'treningów')}';

    return Row(
      children: [
        const Expanded(
          child: Text(
            'Ten tydzień',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text.rich(
          key: const ValueKey('week-summary'),
          TextSpan(
            children: [
              TextSpan(
                text: '$done',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(text: rest),
            ],
          ),
          style: const TextStyle(color: AppColors.textSubtle, fontSize: 13),
        ),
        if (streakWeeks > 0) ...[
          const SizedBox(width: 8),
          _StreakChip(weeks: streakWeeks),
        ],
      ],
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.weeks});

  final int weeks;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Seria: $weeks ${polishPlural(weeks, 'tydzień', 'tygodnie', 'tygodni')} z celem',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.statAmber.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              size: 14,
              color: AppColors.record,
            ),
            const SizedBox(width: 4),
            Text(
              '$weeks tyg.',
              style: const TextStyle(
                color: AppColors.record,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    super.key,
    required this.letter,
    required this.dayNumber,
    required this.caption,
    required this.state,
    required this.color,
    required this.isToday,
    required this.isSelected,
    required this.semanticLabel,
    required this.onTap,
  });

  final String letter;
  final int dayNumber;
  final String caption;
  final WeekDayState state;
  final Color color;
  final bool isToday;
  final bool isSelected;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final todayTint = Color.lerp(color, Colors.white, 0.35)!;
    final captionColor = isToday
        ? todayTint
        : state == WeekDayState.done
        ? AppColors.textLabel
        : AppColors.textMuted;

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Text(
              letter,
              style: TextStyle(
                color: isToday ? todayTint : AppColors.textLabel,
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox.square(
              dimension: 38,
              child: Center(
                child: _DayCircle(
                  key: ValueKey('week-circle-${state.name}'),
                  dayNumber: dayNumber,
                  state: state,
                  color: color,
                  isSelected: isSelected,
                  pulse: state == WeekDayState.today,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: captionColor,
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({
    super.key,
    required this.dayNumber,
    required this.state,
    required this.color,
    required this.isSelected,
    required this.pulse,
  });

  final int dayNumber;
  final WeekDayState state;
  final Color color;
  final bool isSelected;
  final bool pulse;

  static const _plannedFill = Color(0xFF171D2A);
  static const _restBorder = Color(0xFF2A3243);

  @override
  Widget build(BuildContext context) {
    final circle = switch (state) {
      WeekDayState.done => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(
          Icons.check_rounded,
          size: 20,
          color: Color.lerp(color, Colors.black, 0.84),
        ),
      ),
      WeekDayState.today => _TodayPulse(
        enabled: pulse,
        color: color,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Text(
            '$dayNumber',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      WeekDayState.planned => Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: _plannedFill,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNumber',
              style: const TextStyle(
                color: AppColors.textSubtle,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
      WeekDayState.rest => CustomPaint(
        painter: const _DashedCirclePainter(color: _restBorder),
        child: SizedBox.square(
          dimension: 38,
          child: Center(
            child: Text(
              '$dayNumber',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    };

    if (!isSelected) return circle;
    // Wybrany dzień (inny niż dziś) — obwódka w kolorze jego planu.
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Color.lerp(color, Colors.white, 0.2)!,
          width: 1.5,
        ),
      ),
      child: FittedBox(child: circle),
    );
  }
}

/// Rozchodząca się poświata wokół dzisiejszego dnia — 2,4 s, easeOut,
/// w pętli. Wyłączona przy „Ogranicz ruch”.
class _TodayPulse extends StatefulWidget {
  const _TodayPulse({
    required this.enabled,
    required this.color,
    required this.child,
  });

  final bool enabled;
  final Color color;
  final Widget child;

  @override
  State<_TodayPulse> createState() => _TodayPulseState();
}

class _TodayPulseState extends State<_TodayPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _TodayPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.enabled && !reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // Jak `box-shadow` z makiety: 0 → 8 px przez 70% cyklu, potem cisza.
        final t = (_controller.value / 0.7).clamp(0.0, 1.0);
        final eased = Curves.easeOut.transform(t);
        final visible = _controller.isAnimating && t < 1;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: visible
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.45 * (1 - eased)),
                      spreadRadius: 8 * eased,
                    ),
                  ]
                : const [],
          ),
          child: child,
        );
      },
    );
  }
}

/// Przerywany okrąg dnia wolnego.
class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  static const _dashes = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1);
    const step = 2 * math.pi / _dashes;
    for (var i = 0; i < _dashes; i++) {
      canvas.drawArc(rect, i * step, step * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
