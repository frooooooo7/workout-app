import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_pressable.dart';
import '../../../domain/services/history_feed_builder.dart';
import 'history_plan_style.dart';

/// Co pokazuje lista treningów: wszystko, jeden plan albo tylko treningi
/// z rekordami.
sealed class HistoryFilter {
  const HistoryFilter();

  static const all = _AllFilter();
  static const records = _RecordsFilter();

  /// Plan wybrany po [key] z [HistoryPlanOption].
  const factory HistoryFilter.plan(String key) = _PlanFilter;

  bool matches(HistoryFeedEntry entry);
}

class _AllFilter extends HistoryFilter {
  const _AllFilter();

  @override
  bool matches(HistoryFeedEntry entry) => true;
}

class _RecordsFilter extends HistoryFilter {
  const _RecordsFilter();

  @override
  bool matches(HistoryFeedEntry entry) => entry.recordsCount > 0;
}

class _PlanFilter extends HistoryFilter {
  const _PlanFilter(this.key);

  final String key;

  @override
  bool matches(HistoryFeedEntry entry) => historyPlanKey(entry) == key;

  @override
  bool operator ==(Object other) => other is _PlanFilter && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Klucz planu do filtra — nazwa bez wielkości liter; trening bez nazwy
/// planu nie ma klucza i żaden filtr planu go nie łapie.
String? historyPlanKey(HistoryFeedEntry entry) {
  final name = entry.item.plan.name.trim().toLowerCase();
  return name.isEmpty ? null : name;
}

/// Plan, po którym da się zawęzić listę.
class HistoryPlanOption {
  const HistoryPlanOption({required this.key, required this.style});

  final String key;
  final HistoryPlanStyle style;
}

/// Plany z historii, od ostatnio trenowanego.
List<HistoryPlanOption> historyPlanOptions(List<HistoryFeedEntry> entries) {
  final seen = <String, HistoryPlanOption>{};
  for (final entry in entries) {
    final key = historyPlanKey(entry);
    if (key == null || seen.containsKey(key)) continue;
    seen[key] = HistoryPlanOption(
      key: key,
      style: HistoryPlanStyle.of(entry.item),
    );
  }
  return seen.values.toList();
}

/// Pasek filtrów nad listą: Wszystkie, plany z historii (z kolorową kropką)
/// i Rekordy. Przewija się w bok.
class HistoryFilterBar extends StatelessWidget {
  const HistoryFilterBar({
    super.key,
    required this.plans,
    required this.hasRecords,
    required this.selected,
    required this.onSelected,
  });

  final List<HistoryPlanOption> plans;
  final bool hasRecords;
  final HistoryFilter selected;
  final ValueChanged<HistoryFilter> onSelected;

  /// Jeden plan i brak rekordów — nie ma czego zawężać, paska nie ma.
  static bool isUseful({required int plans, required bool hasRecords}) =>
      plans >= 2 || hasRecords;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
        children: [
          _FilterChip(
            label: 'Wszystkie',
            selected: selected == HistoryFilter.all,
            onTap: () => onSelected(HistoryFilter.all),
          ),
          for (final plan in plans)
            _FilterChip(
              label: plan.style.name,
              dot: plan.style.color,
              selected: selected == HistoryFilter.plan(plan.key),
              onTap: () => onSelected(HistoryFilter.plan(plan.key)),
            ),
          if (hasRecords)
            _FilterChip(
              label: 'Rekordy',
              icon: Icons.emoji_events_rounded,
              selected: selected == HistoryFilter.records,
              onTap: () => onSelected(HistoryFilter.records),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Semantics(
        button: true,
        selected: selected,
        excludeSemantics: true,
        label: label,
        child: AppPressable(
          onTap: onTap,
          pressedScale: 0.96,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.textPrimary : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.borderStrong,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dot != null) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                if (icon != null) ...[
                  Icon(icon, size: 15, color: AppColors.record),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? AppColors.background
                        : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
