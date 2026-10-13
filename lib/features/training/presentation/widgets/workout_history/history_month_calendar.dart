import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../domain/models/training_history_models.dart';
import 'history_plan_style.dart';

/// Kalendarz miesiąca w kolorach planów: dzień z treningiem jest podbarwiony
/// kolorem planu, dziś ma biały pierścień. Pod siatką legenda planów z tego
/// miesiąca i seria tygodni z treningiem.
///
/// Stuknięcie dnia z treningiem zawęża listę do tego dnia (drugie — zdejmuje
/// filtr).
class HistoryMonthCalendar extends StatelessWidget {
  const HistoryMonthCalendar({
    super.key,
    required this.month,
    required this.sessions,
    required this.today,
    this.selectedDay,
    this.streakWeeks = 0,
    this.onDayTap,
  });

  final DateTime month;
  final List<TrainingSessionListItem> sessions;

  /// Data bez godziny.
  final DateTime today;
  final DateTime? selectedDay;

  /// Bieżąca seria tygodni z treningiem; pokazywana od dwóch tygodni.
  final int streakWeeks;
  final ValueChanged<DateTime>? onDayTap;

  static const _weekdays = ['P', 'W', 'Ś', 'C', 'P', 'S', 'N'];

  /// Plan dnia — pierwszego treningu tego dnia.
  Map<DateTime, HistoryPlanStyle> _planByDay() {
    final ordered = [...sessions]
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final byDay = <DateTime, HistoryPlanStyle>{};
    for (final session in ordered) {
      final local = session.startedAt.toLocal();
      byDay.putIfAbsent(
        DateTime(local.year, local.month, local.day),
        () => HistoryPlanStyle.of(session),
      );
    }
    return byDay;
  }

  @override
  Widget build(BuildContext context) {
    final planByDay = _planByDay();
    final legend = <String, HistoryPlanStyle>{
      for (final style in planByDay.values) style.name: style,
    };
    final firstWeekday = DateTime(month.year, month.month).weekday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cells = <DateTime?>[
      for (var i = 1; i < firstWeekday; i++) null,
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(month.year, month.month, d),
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                for (final label in _weekdays)
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var row = 0; row * 7 < cells.length; row++)
            Padding(
              padding: EdgeInsets.only(top: row == 0 ? 0 : 2),
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: _cell(
                        row * 7 + col < cells.length
                            ? cells[row * 7 + col]
                            : null,
                        planByDay,
                      ),
                    ),
                ],
              ),
            ),
          if (legend.isNotEmpty || streakWeeks >= 2)
            _CalendarFooter(
              plans: legend.values.toList(),
              streakWeeks: streakWeeks,
            ),
        ],
      ),
    );
  }

  Widget _cell(DateTime? day, Map<DateTime, HistoryPlanStyle> planByDay) {
    if (day == null) return const SizedBox(height: _CalendarDay.size);
    final plan = planByDay[day];
    return _CalendarDay(
      day: day,
      plan: plan,
      isToday: day == today,
      isFuture: day.isAfter(today),
      isSelected: day == selectedDay,
      onTap: plan == null || onDayTap == null ? null : () => onDayTap!(day),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.plan,
    required this.isToday,
    required this.isFuture,
    required this.isSelected,
    this.onTap,
  });

  final DateTime day;
  final HistoryPlanStyle? plan;
  final bool isToday;
  final bool isFuture;
  final bool isSelected;
  final VoidCallback? onTap;

  static const size = 34.0;

  /// Dzień, który jeszcze nie nadszedł — ciszej niż [AppColors.textMuted].
  static const _futureColor = Color(0xFF464F62);

  @override
  Widget build(BuildContext context) {
    final plan = this.plan;
    final Color textColor;
    if (plan != null) {
      textColor = plan.onTint;
    } else if (isToday) {
      textColor = AppColors.textPrimary;
    } else {
      textColor = isFuture ? _futureColor : AppColors.textSecondary;
    }

    final Border? border;
    if (isSelected && plan != null) {
      border = Border.all(color: plan.color, width: 2);
    } else if (isToday) {
      border = Border.all(color: AppColors.textPrimary, width: 2);
    } else {
      border = null;
    }

    final circle = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: plan?.tint(isSelected ? 0.34 : 0.21),
        border: border,
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: textColor,
          fontSize: 13.5,
          fontWeight: plan != null || isToday
              ? FontWeight.w800
              : FontWeight.w700,
        ),
      ),
    );

    return Semantics(
      label: [
        '${day.day}',
        if (isToday) 'dziś',
        if (plan != null) 'trening ${plan.name}',
      ].join(', '),
      selected: isSelected,
      button: onTap != null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(child: circle),
      ),
    );
  }
}

/// Legenda planów miesiąca i seria tygodni z rzędu.
class _CalendarFooter extends StatelessWidget {
  const _CalendarFooter({required this.plans, required this.streakWeeks});

  final List<HistoryPlanStyle> plans;
  final int streakWeeks;

  static const _style = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.fromLTRB(6, AppSpacing.xs, 6, 0),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                for (final plan in plans)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: plan.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          plan.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _style,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (streakWeeks >= 2)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  size: 14,
                  color: AppColors.record,
                ),
                const SizedBox(width: 4),
                Text(
                  '$streakWeeks tyg. z rzędu',
                  style: _style.copyWith(color: AppColors.record),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
