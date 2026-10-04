import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../../training/presentation/widgets/stats/stats_format.dart';
import '../../domain/models/body_weight_entry.dart';
import '../../domain/services/body_weight_trend.dart';
import '../bloc/body_weight_cubit.dart';
import '../utils/profile_details_labels.dart';
import '../widgets/body_weight_chart.dart';
import '../widgets/body_weight_entry_sheet.dart';

const kBodyWeightRoute = '/app/profile/body-weight';
const bodyWeightAddButtonKey = Key('body-weight-add');

/// Waga startowa linijki, gdy nie ma jeszcze żadnego pomiaru.
const _kDefaultWeightKg = 75.0;

/// Dziennik masy ciała: aktualna waga, trend w okresie, wykres i lista
/// pomiarów. Wymaga [BodyWeightCubit] w kontekście.
class BodyWeightScreen extends StatefulWidget {
  const BodyWeightScreen({super.key, this.clock = DateTime.now});

  final DateTime Function() clock;

  @override
  State<BodyWeightScreen> createState() => _BodyWeightScreenState();
}

class _BodyWeightScreenState extends State<BodyWeightScreen> {
  @override
  void initState() {
    super.initState();
    context.read<BodyWeightCubit>().load();
  }

  DateTime get _today {
    final now = widget.clock();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _addEntry() async {
    final cubit = context.read<BodyWeightCubit>();
    final entries = cubit.state.entries ?? const <BodyWeightEntry>[];
    final input = await showBodyWeightEntrySheet(
      context,
      initialDate: _today,
      initialWeightKg: cubit.state.latest?.weightKg ?? _kDefaultWeightKg,
      existingDates: {for (final e in entries) e.date},
      clock: widget.clock,
    );
    if (input == null) return;
    await cubit.save(input.date, input.weightKg);
  }

  Future<void> _editEntry(BodyWeightEntry entry) async {
    final cubit = context.read<BodyWeightCubit>();
    final input = await showBodyWeightEntrySheet(
      context,
      initialDate: entry.date,
      initialWeightKg: entry.weightKg,
      editing: true,
      clock: widget.clock,
    );
    if (input == null || input.weightKg == entry.weightKg) return;
    await cubit.save(entry.date, input.weightKg);
  }

  Future<void> _showEntryActions(BodyWeightEntry entry) async {
    final action = await showAppActionSheet<_EntryAction>(
      context,
      title:
          '${formatStatsLongDate(entry.date)} · ${formatWeightKg(entry.weightKg)}',
      actions: const [
        AppSheetAction(
          value: _EntryAction.edit,
          icon: Icons.edit_outlined,
          label: 'Edytuj',
        ),
        AppSheetAction(
          value: _EntryAction.delete,
          icon: Icons.delete_outline_rounded,
          label: 'Usuń pomiar',
          destructive: true,
        ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case _EntryAction.edit:
        await _editEntry(entry);
      case _EntryAction.delete:
        await context.read<BodyWeightCubit>().delete(entry);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BodyWeightCubit, BodyWeightState>(
      listenWhen: (previous, current) =>
          current.messageId != previous.messageId && current.message != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(state.message!),
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('MASA CIAŁA')),
        floatingActionButton: BlocBuilder<BodyWeightCubit, BodyWeightState>(
          buildWhen: (previous, current) =>
              (previous.entries == null) != (current.entries == null) ||
              previous.saving != current.saving,
          builder: (context, state) {
            if (state.entries == null) return const SizedBox.shrink();
            return FloatingActionButton.extended(
              key: bodyWeightAddButtonKey,
              onPressed: state.saving ? null : _addEntry,
              icon: state.saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.add_rounded),
              label: const Text('Dodaj pomiar'),
            );
          },
        ),
        body: BlocBuilder<BodyWeightCubit, BodyWeightState>(
          builder: (context, state) {
            final cubit = context.read<BodyWeightCubit>();
            final entries = state.entries;
            if (entries == null) {
              if (state.loadError != null) {
                return _LoadError(
                  message: state.loadError!,
                  onRetry: cubit.load,
                );
              }
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: cubit.load,
              child: entries.isEmpty
                  ? const _EmptyState()
                  : _Content(
                      state: state,
                      today: _today,
                      onRangeChanged: cubit.selectRange,
                      onEntryTap: _editEntry,
                      onEntryMore: _showEntryActions,
                    ),
            );
          },
        ),
      ),
    );
  }
}

enum _EntryAction { edit, delete }

class _Content extends StatelessWidget {
  const _Content({
    required this.state,
    required this.today,
    required this.onRangeChanged,
    required this.onEntryTap,
    required this.onEntryMore,
  });

  final BodyWeightState state;
  final DateTime today;
  final ValueChanged<BodyWeightRange> onRangeChanged;
  final ValueChanged<BodyWeightEntry> onEntryTap;
  final ValueChanged<BodyWeightEntry> onEntryMore;

  @override
  Widget build(BuildContext context) {
    final entries = state.entries!;
    final latest = entries.last;
    final inRange = bodyWeightEntriesBetween(
      entries,
      start: state.range.startFor(today),
    );
    final trend = bodyWeightTrend(inRange);
    final newestFirst = entries.reversed.toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.xs,
        AppSpacing.pageGutter,
        // Miejsce na przycisk „Dodaj pomiar”.
        96 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _CurrentWeightCard(latest: latest, trend: trend, today: today),
        const SizedBox(height: AppSpacing.md),
        _RangeChips(selected: state.range, onChanged: onRangeChanged),
        const SizedBox(height: AppSpacing.sm),
        _Card(
          child: SizedBox(
            height: 200,
            child: inRange.length >= 2
                ? Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: BodyWeightChart(entries: inRange),
                  )
                : const Center(
                    child: Text(
                      'Za mało pomiarów w tym okresie, żeby narysować wykres.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Padding(
          padding: EdgeInsets.only(left: AppSpacing.xxs),
          child: Text(
            'Pomiary',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < newestFirst.length; i++)
          _EntryTile(
            key: ValueKey('body-weight-entry-${newestFirst[i].date}'),
            entry: newestFirst[i],
            previous: i + 1 < newestFirst.length ? newestFirst[i + 1] : null,
            onTap: () => onEntryTap(newestFirst[i]),
            onMore: () => onEntryMore(newestFirst[i]),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: child,
    );
  }
}

class _CurrentWeightCard extends StatelessWidget {
  const _CurrentWeightCard({
    required this.latest,
    required this.trend,
    required this.today,
  });

  final BodyWeightEntry latest;
  final BodyWeightTrend? trend;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final t = trend;
    return _Card(
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.xxs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aktualna waga',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatWeightKg(latest.weightKg),
                    key: const Key('body-weight-current'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  Text(
                    'Pomiar: ${formatStatsRelativeDay(latest.date, today)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            if (t != null)
              _ChangeBadge(
                changeKg: t.changeKg,
                caption: 'od ${formatStatsDayMonth(t.first.date)}',
              ),
          ],
        ),
      ),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.changeKg, required this.caption});

  final double changeKg;
  final String caption;

  @override
  Widget build(BuildContext context) {
    // Kierunek bez oceny: spadek nie zawsze jest celem, więc bez
    // czerwieni/zieleni.
    final icon = changeKg > 0
        ? Icons.trending_up_rounded
        : changeKg < 0
        ? Icons.trending_down_rounded
        : Icons.trending_flat_rounded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.statTeal),
            const SizedBox(width: 4),
            Text(
              formatWeightChange(changeKg),
              key: const Key('body-weight-change'),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Text(
          caption,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _RangeChips extends StatelessWidget {
  const _RangeChips({required this.selected, required this.onChanged});

  final BodyWeightRange selected;
  final ValueChanged<BodyWeightRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          for (final range in BodyWeightRange.values)
            Expanded(
              child: Semantics(
                selected: range == selected,
                button: true,
                child: GestureDetector(
                  key: ValueKey('body-weight-range-${range.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (range == selected) return;
                    HapticFeedback.selectionClick();
                    onChanged(range);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: range == selected
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      range.label,
                      style: TextStyle(
                        color: range == selected
                            ? AppColors.onPrimary
                            : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    super.key,
    required this.entry,
    required this.previous,
    required this.onTap,
    required this.onMore,
  });

  final BodyWeightEntry entry;
  final BodyWeightEntry? previous;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final prev = previous;
    final change = prev == null
        ? null
        : ((entry.weightKg - prev.weightKg) * 10).round() / 10;
    return InkWell(
      onTap: onTap,
      onLongPress: onMore,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.xxs),
        child: Row(
          children: [
            Expanded(
              child: Text(
                formatStatsLongDate(entry.date),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            if (change != null && change != 0)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text(
                  formatWeightChange(change),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                  ),
                ),
              ),
            Text(
              formatWeightKg(entry.weightKg),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              tooltip: 'Więcej',
              onPressed: onMore,
              icon: const Icon(
                Icons.more_vert_rounded,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    // ListView, żeby pull-to-refresh działał też przy pustej liście.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
      children: const [
        Icon(
          Icons.monitor_weight_outlined,
          size: 48,
          color: AppColors.textMuted,
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          'Brak pomiarów',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        Text(
          'Zapisuj wagę regularnie, najlepiej o tej samej porze dnia — '
          'tutaj zobaczysz, jak się zmienia.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.strengthWeak,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }
}
