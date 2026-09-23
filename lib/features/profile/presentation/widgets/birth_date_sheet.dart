import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/models/profile_details.dart';
import '../utils/profile_details_labels.dart';

const birthDateSheetConfirmKey = Key('birth-date-sheet-confirm');
const birthDateSheetClearKey = Key('birth-date-sheet-clear');

/// Wynik arkusza: `null` — zamknięty bez zmian; `(date: null)` — usunięto.
typedef BirthDateResult = ({DateTime? date});

/// Arkusz z trzema kołami (dzień / miesiąc / rok) — wiek 16–100 lat.
Future<BirthDateResult?> showBirthDateSheet(
  BuildContext context, {
  DateTime? initial,
  DateTime? today,
}) {
  return showModalBottomSheet<BirthDateResult>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) =>
        _BirthDateSheet(initial: initial, today: today ?? DateTime.now()),
  );
}

class _BirthDateSheet extends StatefulWidget {
  const _BirthDateSheet({required this.initial, required this.today});

  final DateTime? initial;
  final DateTime today;

  @override
  State<_BirthDateSheet> createState() => _BirthDateSheetState();
}

class _BirthDateSheetState extends State<_BirthDateSheet> {
  late final int _minYear = widget.today.year - kMaxUserAge;
  late final int _maxYear = widget.today.year - kMinUserAge;

  late int _day;
  late int _month;
  late int _year;

  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _yearController;

  @override
  void initState() {
    super.initState();
    final start = widget.initial ?? DateTime(widget.today.year - 25, 1, 1);
    _year = start.year.clamp(_minYear, _maxYear);
    _month = start.month;
    _day = start.day;
    _dayController = FixedExtentScrollController(initialItem: _day - 1);
    _monthController = FixedExtentScrollController(initialItem: _month - 1);
    _yearController = FixedExtentScrollController(
      initialItem: _year - _minYear,
    );
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  int get _daysInMonth => DateUtils.getDaysInMonth(_year, _month);

  DateTime get _date => DateTime(_year, _month, _day.clamp(1, _daysInMonth));

  int get _age => fullYearsBetween(_date, widget.today);

  bool get _tooYoung => _age < kMinUserAge;

  void _onMonthOrYearChanged() {
    // 31 → 30/29/28, gdy nowy miesiąc jest krótszy.
    final maxDay = _daysInMonth;
    if (_day > maxDay) {
      _day = maxDay;
      _dayController.jumpToItem(maxDay - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Data urodzenia',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.centerLeft,
                children: [...previous, ?current],
              ),
              child: Text(
                _tooYoung
                    ? 'Musisz mieć co najmniej $kMinUserAge lat.'
                    : '${formatBirthDate(_date)} · ${formatAge(_age)}',
                key: ValueKey(_tooYoung),
                style: TextStyle(
                  color: _tooYoung
                      ? AppColors.strengthWeak
                      : AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pasek zaznaczenia za kołami.
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _Wheel(
                          semanticsLabel: 'Dzień',
                          controller: _dayController,
                          count: _daysInMonth,
                          selected: _day - 1,
                          labelOf: (i) => '${i + 1}',
                          onChanged: (i) => setState(() => _day = i + 1),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: _Wheel(
                          semanticsLabel: 'Miesiąc',
                          controller: _monthController,
                          count: 12,
                          selected: _month - 1,
                          labelOf: (i) => kPolishMonths[i],
                          onChanged: (i) => setState(() {
                            _month = i + 1;
                            _onMonthOrYearChanged();
                          }),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: _Wheel(
                          semanticsLabel: 'Rok',
                          controller: _yearController,
                          count: _maxYear - _minYear + 1,
                          selected: _year - _minYear,
                          labelOf: (i) => '${_minYear + i}',
                          onChanged: (i) => setState(() {
                            _year = _minYear + i;
                            _onMonthOrYearChanged();
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: birthDateSheetConfirmKey,
              onPressed: _tooYoung
                  ? null
                  : () => Navigator.of(context).pop((date: _date)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Gotowe'),
            ),
            if (widget.initial != null)
              TextButton(
                key: birthDateSheetClearKey,
                onPressed: () => Navigator.of(context).pop((date: null)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size.fromHeight(AppSpacing.minTapTarget),
                ),
                child: const Text('Usuń datę'),
              ),
          ],
        ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.semanticsLabel,
    required this.controller,
    required this.count,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  final String semanticsLabel;
  final FixedExtentScrollController controller;
  final int count;
  final int selected;
  final String Function(int index) labelOf;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      value: labelOf(selected),
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 44,
        diameterRatio: 1.6,
        perspective: 0.004,
        overAndUnderCenterOpacity: 0.45,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: (index) {
          HapticFeedback.selectionClick();
          onChanged(index);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, index) {
            final isSelected = index == selected;
            return Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 120),
                style: TextStyle(
                  fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: isSelected ? 18 : 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                child: Text(labelOf(index), maxLines: 1),
              ),
            );
          },
        ),
      ),
    );
  }
}
