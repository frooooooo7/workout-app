import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../domain/models/monthly_training_history.dart';
import '../../../domain/services/history_feed_builder.dart';
import 'history_formatters.dart';
import 'history_month_calendar.dart';
import 'history_month_navigator.dart';
import 'history_session_row.dart';

/// Kalendarz miesiąca w arkuszu od dołu (ikonka w nagłówku Historii).
///
/// Stuknięcie dnia z treningiem pokazuje pod kalendarzem jego sesje, a „Pokaż
/// na liście” zamyka arkusz i woła [onShowOnList] z tym dniem.
Future<void> showHistoryCalendarSheet(
  BuildContext context, {
  required List<HistoryFeedEntry> entries,
  required int streakWeeks,
  required ValueChanged<DateTime> onShowOnList,
  DateTime? today,
}) {
  final now = DateTime.now();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Arkusz przykrywa też dolny pasek nawigacji.
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: AppColors.background,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (sheetContext) => HistoryCalendarSheet(
      entries: entries,
      streakWeeks: streakWeeks,
      today: today ?? DateTime(now.year, now.month, now.day),
      onShowOnList: (day) {
        Navigator.of(sheetContext).pop();
        onShowOnList(day);
      },
    ),
  );
}

class HistoryCalendarSheet extends StatefulWidget {
  const HistoryCalendarSheet({
    super.key,
    required this.entries,
    required this.today,
    required this.onShowOnList,
    this.streakWeeks = 0,
  });

  final List<HistoryFeedEntry> entries;
  final DateTime today;
  final int streakWeeks;
  final ValueChanged<DateTime> onShowOnList;

  @override
  State<HistoryCalendarSheet> createState() => _HistoryCalendarSheetState();
}

class _HistoryCalendarSheetState extends State<HistoryCalendarSheet> {
  late DateTime _month = DateTime(widget.today.year, widget.today.month);
  DateTime? _selectedDay;

  DateTime get _currentMonth => DateTime(widget.today.year, widget.today.month);

  /// Najstarszy miesiąc z treningiem (albo bieżący) — dalej w przeszłość nie
  /// ma po co przewijać.
  DateTime get _firstMonth {
    var first = _currentMonth;
    for (final entry in widget.entries) {
      final day = entry.day;
      final month = DateTime(day.year, day.month);
      if (month.isBefore(first)) first = month;
    }
    return first;
  }

  List<HistoryFeedEntry> _entriesOf(DateTime month) => [
    for (final entry in widget.entries)
      if (entry.day.year == month.year && entry.day.month == month.month) entry,
  ];

  void _goTo(DateTime month) {
    final target = DateTime(month.year, month.month);
    if (target.isBefore(_firstMonth) || target.isAfter(_currentMonth)) return;
    setState(() {
      _month = target;
      _selectedDay = null;
    });
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(widget.today.year, widget.today.month + 1, 0),
      initialDatePickerMode: DatePickerMode.year,
      // Język bierze się z aplikacji (AppLocalization).
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: Theme.of(context).colorScheme.primary,
            surface: Theme.of(context).colorScheme.surface,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _month = DateTime(picked.year, picked.month);
        _selectedDay = null;
      });
    }
  }

  void _toggleDay(DateTime day) {
    setState(() => _selectedDay = _selectedDay == day ? null : day);
  }

  @override
  Widget build(BuildContext context) {
    final monthEntries = _entriesOf(_month);
    final selected = _selectedDay;
    final dayEntries = selected == null
        ? const <HistoryFeedEntry>[]
        : [
            for (final entry in monthEntries)
              if (entry.day == selected) entry,
          ];
    final items = [for (final entry in monthEntries) entry.item];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          HistoryMonthNavigator(
            month: _month,
            stats: MonthlyTrainingStats.fromSessions(items),
            onPrevious: _month.isAfter(_firstMonth)
                ? () => _goTo(DateTime(_month.year, _month.month - 1))
                : null,
            onNext: _month.isBefore(_currentMonth)
                ? () => _goTo(DateTime(_month.year, _month.month + 1))
                : null,
            onPickMonth: _pickMonth,
          ),
          const SizedBox(height: AppSpacing.xs),
          HistoryMonthCalendar(
            month: _month,
            sessions: items,
            today: widget.today,
            selectedDay: selected,
            streakWeeks: widget.streakWeeks,
            onDayTap: _toggleDay,
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: selected == null
                ? const _Hint()
                : _DayPreview(
                    day: selected,
                    entries: dayEntries,
                    onShowOnList: () => widget.onShowOnList(selected),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Text(
        'Stuknij dzień z treningiem, żeby go zobaczyć.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DayPreview extends StatelessWidget {
  const _DayPreview({
    required this.day,
    required this.entries,
    required this.onShowOnList,
  });

  final DateTime day;
  final List<HistoryFeedEntry> entries;
  final VoidCallback onShowOnList;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  formatSessionDay(day),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: onShowOnList,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryVariant,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Pokaż na liście'),
              ),
            ],
          ),
        ),
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          HistorySessionRow(
            session: entries[i].item,
            recordsCount: entries[i].recordsCount,
          ),
        ],
      ],
    );
  }
}
