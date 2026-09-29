import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../domain/models/training_stats.dart';
import '../session_details/session_section_card.dart';
import 'stats_format.dart';

/// Kolor poziomu 0–4: pusty dzień, trzy odcienie [AppColors.primary]
/// i jaśniejszy [AppColors.primaryVariant] dla najcięższych dni.
Color _levelColor(int level) => switch (level) {
  <= 0 => AppColors.chartTrack,
  1 => AppColors.primary.withValues(alpha: 0.32),
  2 => AppColors.primary.withValues(alpha: 0.55),
  3 => AppColors.primary.withValues(alpha: 0.85),
  _ => AppColors.primaryVariant,
};

/// Heatmapa w stylu GitHuba: kolumna = tydzień (od poniedziałku), wiersz =
/// dzień tygodnia, intensywność = liczba serii danego dnia.
class StatsActivityCard extends StatefulWidget {
  const StatsActivityCard({super.key, required this.activity});

  final StatsActivity activity;

  @override
  State<StatsActivityCard> createState() => _StatsActivityCardState();
}

class _StatsActivityCardState extends State<StatsActivityCard> {
  DateTime? _selected;

  @override
  void didUpdateWidget(StatsActivityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = _selected;
    if (selected != null &&
        (selected.isBefore(widget.activity.start) ||
            selected.isAfter(widget.activity.today))) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final thresholds = _Thresholds.of(activity);
    final summary = _summary(activity);

    return SessionSectionCard(
      icon: Icons.calendar_month_rounded,
      title: 'Aktywność',
      trailing: _LevelLegend(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label: 'Mapa aktywności. $summary',
            excludeSemantics: true,
            child: _Heatmap(
              activity: activity,
              thresholds: thresholds,
              selected: _selected,
              onSelect: (day) {
                HapticFeedback.selectionClick();
                setState(() => _selected = _selected == day ? null : day);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _DetailLine(
            text: _selected == null ? summary : _dayLine(_selected!),
            highlighted: _selected != null,
          ),
        ],
      ),
    );
  }

  String _summary(StatsActivity activity) {
    final days = activity.trainingDays;
    final noun = polishPlural(
      days,
      'dzień treningowy',
      'dni treningowe',
      'dni treningowych',
    );
    return '$days $noun w ostatnich ${activity.weeks} tyg.';
  }

  String _dayLine(DateTime day) {
    final title = formatStatsBucketTitle(day, StatsBucket.day);
    final data = widget.activity.dayAt(day);
    if (data == null || data.workouts == 0) return '$title · brak treningu';
    final workouts =
        '${data.workouts} ${polishPlural(data.workouts, 'trening', 'treningi', 'treningów')}';
    final sets =
        '${data.sets} ${polishPlural(data.sets, 'seria', 'serie', 'serii')}';
    return '$title · $workouts · $sets';
  }
}

/// Progi poziomów z kwartyli dni z treningiem — skala dopasowuje się do
/// użytkownika: ktoś, kto robi 10 serii, i ktoś, kto robi 40, widzą pełną
/// paletę.
class _Thresholds {
  const _Thresholds(this.q1, this.q2, this.q3, {this.uniform = false});

  final int q1;
  final int q2;
  final int q3;

  /// Wszystkie dni z treningiem mają tyle samo serii.
  final bool uniform;

  static _Thresholds of(StatsActivity activity) {
    final values = [for (final d in activity.days.values) d.sets]..sort();
    if (values.isEmpty) return const _Thresholds(0, 0, 0);
    if (values.first == values.last) {
      return _Thresholds(
        values.first,
        values.first,
        values.first,
        uniform: true,
      );
    }
    int at(double q) => values[((values.length - 1) * q).round()];
    return _Thresholds(at(0.25), at(0.5), at(0.75));
  }

  int levelOf(ActivityDay? day) {
    if (day == null || day.workouts == 0) return 0;
    if (uniform) return 3;
    final sets = day.sets;
    if (sets <= q1) return 1;
    if (sets <= q2) return 2;
    if (sets <= q3) return 3;
    return 4;
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({
    required this.activity,
    required this.thresholds,
    required this.selected,
    required this.onSelect,
  });

  final StatsActivity activity;
  final _Thresholds thresholds;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  static const _labelWidth = 22.0;
  static const _monthRowHeight = 16.0;
  static const _minCell = 6.0;
  // Na tyle duży, żeby 12 tygodni wypełniło szerokość telefonu, zamiast
  // zostawiać pustkę po prawej.
  static const _maxCell = 24.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final weeks = math.max(1, activity.weeks);
        final available = constraints.maxWidth - _labelWidth;
        // Szczelina 3 px wygląda lepiej, ale przy drobnych kratkach zjada
        // za dużo miejsca — wtedy 2 px.
        var gap = 3.0;
        var cell = (available - gap * (weeks - 1)) / weeks;
        if (cell < 10) {
          gap = 2;
          cell = (available - gap * (weeks - 1)) / weeks;
        }
        cell = cell.clamp(_minCell, _maxCell).floorToDouble();
        final pitch = cell + gap;
        final gridWidth = weeks * cell + (weeks - 1) * gap;
        final gridHeight = 7 * cell + 6 * gap;

        return SizedBox(
          height: _monthRowHeight + gridHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final label in _monthLabels(weeks, pitch))
                Positioned(
                  left: _labelWidth + label.column * pitch,
                  top: 0,
                  child: Text(label.text, style: _labelStyle),
                ),
              for (final row in const [0, 2, 4])
                Positioned(
                  left: 0,
                  top: _monthRowHeight + row * pitch,
                  height: cell,
                  child: Center(
                    child: Text(
                      statsWeekdaysShort[row],
                      style: _labelStyle.copyWith(
                        fontSize: math.min(10.5, cell + 2),
                        height: 1,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: _labelWidth,
                top: _monthRowHeight,
                width: gridWidth,
                height: gridHeight,
                child: GestureDetector(
                  key: const ValueKey('stats-activity-grid'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final p = details.localPosition;
                    final column = (p.dx / pitch).floor();
                    final row = (p.dy / pitch).floor();
                    if (column < 0 || column >= weeks) return;
                    if (row < 0 || row > 6) return;
                    final day = _dayAt(column, row);
                    if (day.isAfter(activity.today)) return;
                    onSelect(day);
                  },
                  child: CustomPaint(
                    painter: _HeatmapPainter(
                      activity: activity,
                      thresholds: thresholds,
                      selected: selected,
                      weeks: weeks,
                      cell: cell,
                      gap: gap,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  DateTime _dayAt(int column, int row) => DateTime(
    activity.start.year,
    activity.start.month,
    activity.start.day + column * 7 + row,
  );

  /// Skrót miesiąca nad kolumną, w której ten miesiąc się zaczyna. Etykieta
  /// potrzebuje ok. 24 px — bliższe sąsiadki pomijamy, żeby się nie nakładały.
  List<({int column, String text})> _monthLabels(int weeks, double pitch) {
    final minColumns = math.max(2, (24 / pitch).ceil());
    final candidates = <({int column, String text})>[];
    for (var c = 0; c < weeks; c++) {
      final monday = _dayAt(c, 0);
      final sunday = _dayAt(c, 6);
      if (c == 0) {
        // Pierwsza kolumna podpisuje miesiąc, w którym zaczyna się siatka,
        // o ile nowy miesiąc nie wchodzi w tej samej kolumnie.
        final month = monday.day == 1 || sunday.month == monday.month
            ? monday.month
            : sunday.month;
        candidates.add((column: 0, text: statsMonthsShort[month - 1]));
        continue;
      }
      if (monday.day == 1 || sunday.month != monday.month) {
        candidates.add((column: c, text: statsMonthsShort[sunday.month - 1]));
      }
    }
    final result = <({int column, String text})>[];
    for (final label in candidates) {
      if (result.isNotEmpty && label.column - result.last.column < minColumns) {
        // Pierwsza (przycięta) kolumna ustępuje pełnemu miesiącowi.
        if (result.length == 1 && result.first.column == 0) {
          result[0] = label;
        }
        continue;
      }
      result.add(label);
    }
    return result;
  }
}

const _labelStyle = TextStyle(
  color: AppColors.textMuted,
  fontSize: 10.5,
  fontWeight: FontWeight.w500,
);

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.activity,
    required this.thresholds,
    required this.selected,
    required this.weeks,
    required this.cell,
    required this.gap,
  });

  final StatsActivity activity;
  final _Thresholds thresholds;
  final DateTime? selected;
  final int weeks;
  final double cell;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final pitch = cell + gap;
    final radius = Radius.circular(math.max(1.5, cell * 0.22));
    final fill = Paint();
    final start = activity.start;
    final today = activity.today;

    for (var c = 0; c < weeks; c++) {
      for (var r = 0; r < 7; r++) {
        final day = DateTime(start.year, start.month, start.day + c * 7 + r);
        // Przyszłe dni bieżącego tygodnia zostają puste.
        if (day.isAfter(today)) continue;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(c * pitch, r * pitch, cell, cell),
          radius,
        );
        fill.color = _levelColor(thresholds.levelOf(activity.dayAt(day)));
        canvas.drawRRect(rect, fill);

        final isSelected = day == selected;
        if (isSelected || day == today) {
          canvas.drawRRect(
            rect.deflate(0.5),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = isSelected ? 1.5 : 1
              ..color = isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary.withValues(alpha: 0.7),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) =>
      old.activity != activity ||
      old.selected != selected ||
      old.cell != cell ||
      old.gap != gap ||
      old.weeks != weeks;
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.text, required this.highlighted});

  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.surfaceVariant
            : AppColors.surfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: highlighted ? AppColors.textPrimary : AppColors.textSecondary,
          fontSize: 12.5,
          fontWeight: highlighted ? FontWeight.w600 : FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _LevelLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppColors.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('mniej', style: style),
          const SizedBox(width: 5),
          for (var level = 0; level < 5; level++)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: _levelColor(level),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          const SizedBox(width: 3),
          const Text('więcej', style: style),
        ],
      ),
    );
  }
}
