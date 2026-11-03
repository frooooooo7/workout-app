import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_tab_header.dart';
import '../../../domain/models/monthly_training_history.dart';
import '../../../domain/services/history_feed_builder.dart';
import '../../../domain/services/training_summary_calculator.dart';
import '../session_details/session_details_formatters.dart';
import 'history_formatters.dart';
import 'history_session_card.dart';

/// Wiersz listy w obrębie miesiąca: nagłówek tygodnia albo dzień z kartami.
sealed class HistoryFeedRow {
  const HistoryFeedRow();
}

class HistoryWeekRow extends HistoryFeedRow {
  const HistoryWeekRow({required this.weekStart, this.showGoal = true});

  /// Poniedziałek tygodnia.
  final DateTime weekStart;

  /// Tydzień przecięty granicą miesiąca dostaje nagłówek w obu miesiącach,
  /// ale licznik celu tylko w pierwszym z nich.
  final bool showGoal;
}

class HistoryDayRow extends HistoryFeedRow {
  const HistoryDayRow({required this.day, required this.entries});

  final DateTime day;
  final List<HistoryFeedEntry> entries;
}

/// Treningi jednego miesiąca z nagłówkami tygodni i dniami.
class HistoryMonthSection {
  const HistoryMonthSection({
    required this.month,
    required this.entries,
    required this.rows,
  });

  final DateTime month;
  final List<HistoryFeedEntry> entries;
  final List<HistoryFeedRow> rows;
}

/// Dzieli listę (od najnowszego) na miesiące, a miesiące na tygodnie i dni.
List<HistoryMonthSection> groupHistoryFeed(List<HistoryFeedEntry> entries) {
  final sections = <HistoryMonthSection>[];
  final seenWeeks = <DateTime>{};

  var index = 0;
  while (index < entries.length) {
    final local = entries[index].item.startedAt.toLocal();
    final month = DateTime(local.year, local.month);
    final inMonth = <HistoryFeedEntry>[];
    while (index < entries.length) {
      final l = entries[index].item.startedAt.toLocal();
      if (l.year != month.year || l.month != month.month) break;
      inMonth.add(entries[index]);
      index++;
    }

    final rows = <HistoryFeedRow>[];
    DateTime? currentWeek;
    DateTime? currentDay;
    var dayEntries = <HistoryFeedEntry>[];
    void flushDay() {
      if (currentDay != null) {
        rows.add(HistoryDayRow(day: currentDay, entries: dayEntries));
      }
      dayEntries = [];
    }

    for (final entry in inMonth) {
      final day = entry.day;
      final week = TrainingSummaryCalculator.startOfWeek(day);
      if (currentDay != day) {
        flushDay();
        currentDay = day;
        if (currentWeek != week) {
          currentWeek = week;
          rows.add(
            HistoryWeekRow(weekStart: week, showGoal: seenWeeks.add(week)),
          );
        }
      }
      dayEntries.add(entry);
    }
    flushDay();

    sections.add(
      HistoryMonthSection(month: month, entries: inMonth, rows: rows),
    );
  }
  return sections;
}

/// Ile treningów padło w którym tygodniu (klucz: poniedziałek).
Map<DateTime, int> workoutsPerWeek(Iterable<HistoryFeedEntry> entries) {
  final counts = <DateTime, int>{};
  for (final entry in entries) {
    counts.update(
      TrainingSummaryCalculator.startOfWeek(entry.day),
      (v) => v + 1,
      ifAbsent: () => 1,
    );
  }
  return counts;
}

/// Ciągła lista treningów: nagłówek miesiąca (przyklejony do góry, z sumą
/// miesiąca), pod nim tygodnie z licznikiem celu i dni z kartami.
///
/// Wiersze budują się leniwie, więc długa historia nie kosztuje. [onRowMounted]
/// i [onRowUnmounted] mówią, które wiersze są akurat zbudowane — po to, żeby
/// przewinąć do dnia, którego jeszcze nie ma na ekranie (patrz `showDay`
/// w panelu sesji).
class HistoryFeedSliver extends StatelessWidget {
  const HistoryFeedSliver({
    super.key,
    required this.sections,
    required this.today,
    required this.dayKeyFor,
    this.weekCounts = const {},
    this.weeklyGoal,
    this.highlightedDay,
    this.onRowMounted,
    this.onRowUnmounted,
  });

  final List<HistoryMonthSection> sections;
  final DateTime today;

  /// Klucz bloku dnia — po nim panel przewija do dnia z kalendarza.
  final GlobalKey Function(DateTime day) dayKeyFor;

  /// Wszystkie treningi tygodnia (bez filtra) — licznik celu nie powinien
  /// zmieniać się wraz z filtrem planu.
  final Map<DateTime, int> weekCounts;

  /// Cel z profilu; `null` — bez liczników.
  final int? weeklyGoal;

  final DateTime? highlightedDay;
  final ValueChanged<int>? onRowMounted;
  final ValueChanged<int>? onRowUnmounted;

  /// Licznik celu pokazujemy dla ostatniego kwartału — starsze tygodnie
  /// zasypałyby listę „2 z 4”, choć cel mógł być wtedy inny.
  static const goalWeeksShown = 12;

  /// Numer wiersza w całej liście (z nagłówkami miesięcy nie liczymy).
  static List<int> rowBases(List<HistoryMonthSection> sections) {
    final bases = <int>[];
    var total = 0;
    for (final section in sections) {
      bases.add(total);
      total += section.rows.length;
    }
    return bases;
  }

  @override
  Widget build(BuildContext context) {
    final thisWeek = TrainingSummaryCalculator.startOfWeek(today);
    final lastWeek = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7);
    final goalSince = DateTime(
      thisWeek.year,
      thisWeek.month,
      thisWeek.day - 7 * (goalWeeksShown - 1),
    );
    final bases = rowBases(sections);

    return SliverMainAxisGroup(
      slivers: [
        // Każdy miesiąc we własnej grupie: przyklejony nagłówek zostaje na górze
        // tylko do końca swojego miesiąca, a następny go wypycha. W jednej
        // wspólnej grupie nagłówki wszystkich miesięcy układałyby się w stos.
        for (var s = 0; s < sections.length; s++)
          SliverMainAxisGroup(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _MonthHeaderDelegate(
                  month: sections[s].month,
                  stats: MonthlyTrainingStats.fromSessions([
                    for (final e in sections[s].entries) e.item,
                  ]),
                ),
              ),
              SliverList.builder(
                itemCount: sections[s].rows.length,
                itemBuilder: (context, i) {
                  final row = sections[s].rows[i];
                  final child = switch (row) {
                    HistoryWeekRow() => _WeekHeader(
                      weekStart: row.weekStart,
                      title: row.weekStart == thisWeek
                          ? 'Ten tydzień'
                          : row.weekStart == lastWeek
                          ? 'Poprzedni tydzień'
                          : null,
                      goal:
                          row.showGoal &&
                              !row.weekStart.isBefore(goalSince) &&
                              weeklyGoal != null
                          ? (
                              done: weekCounts[row.weekStart] ?? 0,
                              goal: weeklyGoal!,
                            )
                          : null,
                    ),
                    HistoryDayRow() => KeyedSubtree(
                      key: dayKeyFor(row.day),
                      child: HistoryDayBlock(
                        day: row.day,
                        entries: row.entries,
                        highlighted: row.day == highlightedDay,
                      ),
                    ),
                  };
                  return _RowProbe(
                    index: bases[s] + i,
                    onMounted: onRowMounted,
                    onUnmounted: onRowUnmounted,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.pageGutter,
                      ),
                      child: child,
                    ),
                  );
                },
              ),
            ],
          ),
      ],
    );
  }
}

/// Zgłasza, że wiersz o numerze [index] jest (albo przestał być) na ekranie.
class _RowProbe extends StatefulWidget {
  const _RowProbe({
    required this.index,
    required this.child,
    this.onMounted,
    this.onUnmounted,
  });

  final int index;
  final Widget child;
  final ValueChanged<int>? onMounted;
  final ValueChanged<int>? onUnmounted;

  @override
  State<_RowProbe> createState() => _RowProbeState();
}

class _RowProbeState extends State<_RowProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMounted?.call(widget.index);
  }

  @override
  void didUpdateWidget(_RowProbe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      oldWidget.onUnmounted?.call(oldWidget.index);
      widget.onMounted?.call(widget.index);
    }
  }

  @override
  void dispose() {
    widget.onUnmounted?.call(widget.index);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Nagłówek miesiąca przyklejony do góry: nazwa i suma miesiąca. Dopóki lista
/// stoi na początku, jest przezroczysty — poświata zakładki nie dostaje
/// ciemnego paska.
class _MonthHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _MonthHeaderDelegate({required this.month, required this.stats});

  final DateTime month;
  final MonthlyTrainingStats stats;

  static const _height = 40.0;
  static final _neverScrolled = ValueNotifier<bool>(false);

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final summary = [
      formatWorkoutCount(stats.totalSessions),
      formatHoursMinutes(stats.totalDurationSec),
      if (stats.totalVolumeKg > 0) formatVolumeKg(stats.totalVolumeKg),
    ].join(' · ');

    // `overlapsContent` w grupie slivers bywa zawsze fałszywe, więc o tle
    // decyduje przewinięcie zakładki: na początku widać poświatę, po
    // przewinięciu nagłówek zasłania karty, które pod nim przesuwają się.
    final scrolled = AppTabBackground.scrolledOf(context);
    return ValueListenableBuilder<bool>(
      valueListenable: scrolled ?? _neverScrolled,
      builder: (context, isScrolled, child) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
        color: isScrolled ? AppColors.background : Colors.transparent,
        alignment: Alignment.centerLeft,
        child: child,
      ),
      child: _row(summary),
    );
  }

  Widget _row(String summary) {
    return Row(
      children: [
        Semantics(
          header: true,
          child: Text(
            formatMonthYear(month).toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                summary,
                maxLines: 1,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_MonthHeaderDelegate oldDelegate) =>
      oldDelegate.month != month ||
      oldDelegate.stats.totalSessions != stats.totalSessions ||
      oldDelegate.stats.totalVolumeKg != stats.totalVolumeKg ||
      oldDelegate.stats.totalDurationSec != stats.totalDurationSec;
}

/// Nagłówek tygodnia: nazwa (albo sam zakres dat) i licznik celu.
class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.weekStart, this.title, this.goal});

  final DateTime weekStart;

  /// „Ten tydzień” / „Poprzedni tydzień”; starsze tygodnie mają tylko daty.
  final String? title;

  final ({int done, int goal})? goal;

  @override
  Widget build(BuildContext context) {
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 6,
    );
    final range = formatWeekRange(weekStart, weekEnd);
    final goal = this.goal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, AppSpacing.xs, 0, AppSpacing.xs),
      child: SizedBox(
        height: 28,
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: title ?? range),
                    if (title != null)
                      TextSpan(
                        text: ' · $range',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (goal != null) ...[
              const SizedBox(width: AppSpacing.xs),
              _GoalPill(done: goal.done, goal: goal.goal),
            ],
          ],
        ),
      ),
    );
  }
}

/// `1 z 4`; po zrobieniu celu zielone, z ptaszkiem.
class _GoalPill extends StatelessWidget {
  const _GoalPill({required this.done, required this.goal});

  final int done;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final met = done >= goal;
    final color = met ? AppColors.success : AppColors.primaryVariant;
    return Semantics(
      label: 'Cel tygodnia: $done z $goal',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (met) ...[
              Icon(Icons.check_circle_rounded, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              '$done z $goal',
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
