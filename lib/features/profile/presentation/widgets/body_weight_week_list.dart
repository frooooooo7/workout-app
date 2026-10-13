import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../training/presentation/widgets/stats/stats_format.dart';
import '../../domain/models/body_weight_entry.dart';
import '../../domain/services/body_weight_trend.dart';
import '../utils/body_weight_format.dart';
import '../utils/profile_details_labels.dart';

/// Linia między tygodniami — ciszej niż [AppColors.border].
const _dividerColor = Color(0xFF171E2B);

/// Lista pomiarów pogrupowana w tygodnie (średnia i zmiana względem
/// poprzedniego tygodnia). Dotknięcie tygodnia rozwija jego pomiary — każdy
/// można edytować (dotknięcie) albo usunąć z menu ⋯.
class BodyWeightWeekList extends StatefulWidget {
  const BodyWeightWeekList({
    super.key,
    required this.weeks,
    required this.onEntryTap,
    required this.onEntryMore,
    this.goal,
  });

  /// Od najnowszego.
  final List<BodyWeightWeek> weeks;
  final ValueChanged<BodyWeightEntry> onEntryTap;
  final ValueChanged<BodyWeightEntry> onEntryMore;

  /// Kolorowanie zmian: zielone, gdy przybliżają do celu.
  final BodyWeightGoalProgress? goal;

  @override
  State<BodyWeightWeekList> createState() => _BodyWeightWeekListState();
}

class _BodyWeightWeekListState extends State<BodyWeightWeekList> {
  final _expanded = <DateTime>{};

  void _toggle(DateTime week) => setState(() {
    if (!_expanded.remove(week)) _expanded.add(week);
  });

  @override
  Widget build(BuildContext context) {
    final count = widget.weeks.fold<int>(0, (n, w) => n + w.entries.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: const Text(
                    'Tygodnie',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Text(
                formatBodyWeightCount(count),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < widget.weeks.length; i++)
          _WeekSection(
            key: ValueKey('body-weight-week-${widget.weeks[i].start}'),
            week: widget.weeks[i],
            goal: widget.goal,
            expanded: _expanded.contains(widget.weeks[i].start),
            last: i == widget.weeks.length - 1,
            onToggle: () => _toggle(widget.weeks[i].start),
            onEntryTap: widget.onEntryTap,
            onEntryMore: widget.onEntryMore,
          ),
      ],
    );
  }
}

class _WeekSection extends StatelessWidget {
  const _WeekSection({
    super.key,
    required this.week,
    required this.goal,
    required this.expanded,
    required this.last,
    required this.onToggle,
    required this.onEntryTap,
    required this.onEntryMore,
  });

  final BodyWeightWeek week;
  final BodyWeightGoalProgress? goal;
  final bool expanded;
  final bool last;
  final VoidCallback onToggle;
  final ValueChanged<BodyWeightEntry> onEntryTap;
  final ValueChanged<BodyWeightEntry> onEntryMore;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final count = week.entries.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: _dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 50),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatBodyWeightWeek(week.start, week.end),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              count > 1
                                  ? '${formatBodyWeightCount(count)} · śr.'
                                  : formatBodyWeightCount(count),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatWeightKg(week.averageKg),
                        style: AppTextStyles.number(size: 20),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 52,
                        child: _WeekChange(changeKg: week.changeKg, goal: goal),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.expand_more_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Column(
                      children: [
                        for (final entry in week.entries)
                          _EntryRow(
                            key: ValueKey('body-weight-entry-${entry.date}'),
                            entry: entry,
                            onTap: () => onEntryTap(entry),
                            onMore: () => onEntryMore(entry),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _WeekChange extends StatelessWidget {
  const _WeekChange({required this.changeKg, required this.goal});

  final double? changeKg;
  final BodyWeightGoalProgress? goal;

  @override
  Widget build(BuildContext context) {
    final change = changeKg;
    if (change == null) return const SizedBox.shrink();
    final arrow = change < 0
        ? '↓ '
        : change > 0
        ? '↑ '
        : '';
    final towardGoal = goal?.isTowardGoal(change) ?? false;
    return Text(
      '$arrow${formatBodyWeightDelta(change)}',
      textAlign: TextAlign.right,
      semanticsLabel:
          '${change < 0 ? 'spadek' : 'wzrost'} o '
          '${formatBodyWeightDelta(change)} ${WeightUnits.current.label}',
      style: AppTextStyles.tabular(
        TextStyle(
          color: towardGoal ? AppColors.success : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onMore,
  });

  final BodyWeightEntry entry;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final weekday = statsWeekdaysLong[entry.date.weekday - 1];
    return InkWell(
      onTap: onTap,
      onLongPress: onMore,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$weekday, ${formatStatsLongDate(entry.date)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              formatWeightKg(entry.weightKg),
              style: AppTextStyles.tabular(
                const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Więcej',
              visualDensity: VisualDensity.compact,
              onPressed: onMore,
              icon: const Icon(
                Icons.more_horiz_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
