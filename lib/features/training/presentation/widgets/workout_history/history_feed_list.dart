import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_tab_header.dart';
import '../../../domain/models/monthly_training_history.dart';
import '../../../domain/services/history_feed_builder.dart';
import '../session_details/session_details_formatters.dart';
import 'history_compact_row.dart';
import 'history_formatters.dart';

/// Treningi jednego miesiąca, które mają wiersz na liście (bez treningu z karty
/// „Ostatni trening”). Suma w nagłówku liczy dokładnie te wiersze.
class HistoryMonthSection {
  const HistoryMonthSection({required this.month, required this.rows});

  final DateTime month;
  final List<HistoryFeedEntry> rows;
}

/// Dzieli listę (od najnowszego) na miesiące. Trening [exceptId] — ten z karty
/// „Ostatni trening” — nie dostaje wiersza ani nie wchodzi do sumy miesiąca;
/// miesiąc bez wierszy znika.
List<HistoryMonthSection> groupHistoryFeed(
  List<HistoryFeedEntry> entries, {
  String? exceptId,
}) {
  final sections = <HistoryMonthSection>[];
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
    final rows = [
      for (final entry in inMonth)
        if (entry.item.id != exceptId) entry,
    ];
    if (rows.isEmpty) continue;
    sections.add(HistoryMonthSection(month: month, rows: rows));
  }
  return sections;
}

/// „Wcześniej”: jedna karta na miesiąc ze zwartymi wierszami treningów,
/// nagłówek miesiąca (przyklejony do góry, z sumą miesiąca) nad każdą.
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
    this.highlightedDay,
    this.onRowMounted,
    this.onRowUnmounted,
  });

  final List<HistoryMonthSection> sections;
  final DateTime today;

  /// Klucz pierwszego wiersza dnia — po nim panel przewija do dnia z kalendarza.
  final GlobalKey Function(DateTime day) dayKeyFor;

  final DateTime? highlightedDay;
  final ValueChanged<int>? onRowMounted;
  final ValueChanged<int>? onRowUnmounted;

  /// Numer pierwszego wiersza każdego miesiąca w całej liście.
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
                  showYear: sections[s].month.year != today.year,
                  isFirst: s == 0,
                  stats: MonthlyTrainingStats.fromSessions([
                    for (final e in sections[s].rows) e.item,
                  ]),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                  left: AppSpacing.pageGutter,
                  right: AppSpacing.pageGutter,
                  bottom: s == sections.length - 1 ? 0 : AppSpacing.sm,
                ),
                sliver: SliverList.builder(
                  itemCount: sections[s].rows.length,
                  itemBuilder: (context, i) {
                    final rows = sections[s].rows;
                    final entry = rows[i];
                    Widget row = HistoryCompactRow(
                      entry: entry,
                      isFirst: i == 0,
                      isLast: i == rows.length - 1,
                      highlighted: entry.day == highlightedDay,
                    );
                    // Klucz ma tylko pierwszy trening dnia — GlobalKey musi
                    // być jeden.
                    if (i == 0 || rows[i - 1].day != entry.day) {
                      row = KeyedSubtree(key: dayKeyFor(entry.day), child: row);
                    }
                    return _RowProbe(
                      index: bases[s] + i,
                      onMounted: onRowMounted,
                      onUnmounted: onRowUnmounted,
                      child: row,
                    );
                  },
                ),
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
  const _MonthHeaderDelegate({
    required this.month,
    required this.stats,
    required this.isFirst,
    required this.showYear,
  });

  final DateTime month;
  final MonthlyTrainingStats stats;

  /// Pierwszy miesiąc otwiera sekcję „Wcześniej” — jej tytuł stoi po lewej,
  /// a nazwa miesiąca przechodzi do podsumowania.
  final bool isFirst;

  /// Miesiąc z innego roku niż bieżący dostaje rok w nazwie.
  final bool showYear;

  static const _height = 44.0;
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
    final monthName = showYear
        ? formatMonthYear(month)
        : formatMonthName(month);
    final summary = [
      if (isFirst) monthName,
      formatWorkoutCount(stats.totalSessions),
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageGutter + 2,
          AppSpacing.xs,
          AppSpacing.pageGutter + 2,
          2,
        ),
        color: isScrolled ? AppColors.background : Colors.transparent,
        alignment: Alignment.centerLeft,
        child: child,
      ),
      child: _row(isFirst ? 'Wcześniej' : monthName, summary),
    );
  }

  Widget _row(String title, String summary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: isFirst
                ? const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  )
                : const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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
                  fontSize: 13,
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
      oldDelegate.isFirst != isFirst ||
      oldDelegate.showYear != showYear ||
      oldDelegate.stats.totalSessions != stats.totalSessions ||
      oldDelegate.stats.totalVolumeKg != stats.totalVolumeKg ||
      oldDelegate.stats.totalDurationSec != stats.totalDurationSec;
}
