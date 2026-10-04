import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../../training/presentation/widgets/stats/stats_format.dart';
import '../../domain/models/body_measurement_entry.dart';
import '../bloc/body_measurements_cubit.dart';
import '../utils/body_measurement_format.dart';
import '../widgets/body_measurement_chart.dart';
import '../widgets/body_measurement_entry_sheet.dart';

const kBodyMeasurementsRoute = '/app/profile/body-measurements';
const bodyMeasurementsAddButtonKey = Key('body-measurements-add');

/// Kafelek ostatniej wartości pomiaru (testy).
Key bodyMeasurementTileKey(BodyMeasurementField field) =>
    ValueKey('body-measurement-tile-${field.name}');

/// Dziennik pomiarów ciała: ostatnie wartości ze zmianą, wykres wybranego
/// pomiaru i historia wpisów. Wymaga [BodyMeasurementsCubit] w kontekście.
class BodyMeasurementsScreen extends StatefulWidget {
  const BodyMeasurementsScreen({super.key, this.clock = DateTime.now});

  final DateTime Function() clock;

  @override
  State<BodyMeasurementsScreen> createState() => _BodyMeasurementsScreenState();
}

class _BodyMeasurementsScreenState extends State<BodyMeasurementsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<BodyMeasurementsCubit>().load();
  }

  DateTime get _today {
    final now = widget.clock();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _addEntry() async {
    final cubit = context.read<BodyMeasurementsCubit>();
    final entries = cubit.state.entries ?? const <BodyMeasurementEntry>[];
    final entry = await showBodyMeasurementEntrySheet(
      context,
      initialDate: _today,
      hints: _latestValues(entries),
      existingDates: {for (final e in entries) e.date},
      clock: widget.clock,
    );
    if (entry == null) return;
    await cubit.save(entry);
  }

  Future<void> _editEntry(BodyMeasurementEntry entry) async {
    final cubit = context.read<BodyMeasurementsCubit>();
    final edited = await showBodyMeasurementEntrySheet(
      context,
      initialDate: entry.date,
      initial: entry,
      clock: widget.clock,
    );
    if (edited == null || edited == entry) return;
    await cubit.save(edited);
  }

  Future<void> _showEntryActions(BodyMeasurementEntry entry) async {
    final action = await showAppActionSheet<_EntryAction>(
      context,
      title: formatStatsLongDate(entry.date),
      actions: const [
        AppSheetAction(
          value: _EntryAction.edit,
          icon: Icons.edit_outlined,
          label: 'Edytuj',
        ),
        AppSheetAction(
          value: _EntryAction.delete,
          icon: Icons.delete_outline_rounded,
          label: 'Usuń pomiary',
          destructive: true,
        ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case _EntryAction.edit:
        await _editEntry(entry);
      case _EntryAction.delete:
        await context.read<BodyMeasurementsCubit>().delete(entry);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BodyMeasurementsCubit, BodyMeasurementsState>(
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
        appBar: AppBar(title: const Text('POMIARY CIAŁA')),
        floatingActionButton:
            BlocBuilder<BodyMeasurementsCubit, BodyMeasurementsState>(
              buildWhen: (previous, current) =>
                  (previous.entries == null) != (current.entries == null) ||
                  previous.saving != current.saving,
              builder: (context, state) {
                if (state.entries == null) return const SizedBox.shrink();
                return FloatingActionButton.extended(
                  key: bodyMeasurementsAddButtonKey,
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
                  label: const Text('Dodaj pomiary'),
                );
              },
            ),
        body: BlocBuilder<BodyMeasurementsCubit, BodyMeasurementsState>(
          builder: (context, state) {
            final cubit = context.read<BodyMeasurementsCubit>();
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
                      onFieldSelected: cubit.selectField,
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

/// Ostatnia znana wartość każdego pomiaru.
Map<BodyMeasurementField, double> _latestValues(
  List<BodyMeasurementEntry> sorted,
) => {for (final e in sorted) ...e.values};

enum _EntryAction { edit, delete }

class _Content extends StatelessWidget {
  const _Content({
    required this.state,
    required this.today,
    required this.onFieldSelected,
    required this.onEntryTap,
    required this.onEntryMore,
  });

  final BodyMeasurementsState state;
  final DateTime today;
  final ValueChanged<BodyMeasurementField> onFieldSelected;
  final ValueChanged<BodyMeasurementEntry> onEntryTap;
  final ValueChanged<BodyMeasurementEntry> onEntryMore;

  @override
  Widget build(BuildContext context) {
    final entries = state.entries!;
    final selected = state.selectedField;
    final series = {
      for (final field in BodyMeasurementField.values)
        field: bodyMeasurementSeries(entries, field),
    };
    final measured = [
      for (final field in BodyMeasurementField.values)
        if (series[field]!.isNotEmpty) field,
    ];
    final selectedSeries = series[selected]!;
    final newestFirst = entries.reversed.toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.xs,
        AppSpacing.pageGutter,
        // Miejsce na przycisk „Dodaj pomiary”.
        96 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - AppSpacing.sm) / 2;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final field in measured)
                  SizedBox(
                    width: width,
                    child: _LatestTile(
                      key: bodyMeasurementTileKey(field),
                      field: field,
                      series: series[field]!,
                      selected: field == selected,
                      onTap: () {
                        if (field == selected) return;
                        HapticFeedback.selectionClick();
                        onFieldSelected(field);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.xxs,
                  bottom: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selected.label,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (selectedSeries.length >= 2)
                      Text(
                        '${formatMeasurementChange(selected, _change(selectedSeries.first.value, selectedSeries.last.value))}'
                        ' od ${formatStatsDayMonth(selectedSeries.first.date)}',
                        key: const Key('body-measurements-change'),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 190,
                child: selectedSeries.length >= 2
                    ? Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: BodyMeasurementChart(
                          field: selected,
                          points: selectedSeries,
                        ),
                      )
                    : const Center(
                        child: Text(
                          'Dodaj co najmniej dwa pomiary, żeby zobaczyć wykres.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Padding(
          padding: EdgeInsets.only(left: AppSpacing.xxs),
          child: Text(
            'Historia',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final entry in newestFirst)
          _EntryTile(
            key: ValueKey('body-measurements-entry-${entry.date}'),
            entry: entry,
            today: today,
            onTap: () => onEntryTap(entry),
            onMore: () => onEntryMore(entry),
          ),
      ],
    );
  }
}

/// Zaokrąglona do 0,1, jak same pomiary.
double _change(double from, double to) => ((to - from) * 10).round() / 10;

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

class _LatestTile extends StatelessWidget {
  const _LatestTile({
    super.key,
    required this.field,
    required this.series,
    required this.selected,
    required this.onTap,
  });

  final BodyMeasurementField field;
  final List<BodyMeasurementPoint> series;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final latest = series.last;
    final change = series.length >= 2
        ? _change(series[series.length - 2].value, latest.value)
        : null;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected
                    ? AppColors.statTeal
                    : AppColors.border.withValues(alpha: 0.8),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatMeasurement(field, latest.value),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  change == null
                      ? formatStatsDayMonth(latest.date)
                      : '${formatMeasurementChange(field, change)} · '
                            '${formatStatsDayMonth(latest.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
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

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    super.key,
    required this.entry,
    required this.today,
    required this.onTap,
    required this.onMore,
  });

  final BodyMeasurementEntry entry;
  final DateTime today;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final summary = [
      for (final field in BodyMeasurementField.values)
        if (entry[field] case final value?)
          '${measurementShortLabel(field)} ${formatMeasurement(field, value)}',
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      onLongPress: onMore,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.xxs, top: 4, bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatStatsLongDate(entry.date),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
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
        Icon(Icons.straighten_rounded, size: 48, color: AppColors.textMuted),
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
          'Mierz obwody co kilka tygodni, rano i w tym samym miejscu — '
          'tutaj zobaczysz, jak zmienia się sylwetka.',
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
