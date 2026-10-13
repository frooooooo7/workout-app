import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_action_sheet.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../training/presentation/widgets/stats/stats_format.dart';
import '../../domain/models/body_weight_entry.dart';
import '../../domain/services/body_weight_trend.dart';
import '../bloc/body_weight_cubit.dart';
import '../utils/profile_details_labels.dart';
import '../widgets/body_weight_add_button.dart';
import '../widgets/body_weight_chart_card.dart';
import '../widgets/body_weight_current_section.dart';
import '../widgets/body_weight_entry_sheet.dart';
import '../widgets/body_weight_goal_card.dart';
import '../widgets/body_weight_goal_sheet.dart';
import '../widgets/body_weight_range_tabs.dart';
import '../widgets/body_weight_stat_tiles.dart';
import '../widgets/body_weight_week_list.dart';
import 'body_measurements_screen.dart';

const kBodyWeightRoute = '/app/profile/body-weight';
const bodyWeightAddButtonKey = Key('body-weight-add');
const bodyWeightMeasurementsButtonKey = Key('body-weight-measurements');

/// Waga startowa linijki, gdy nie ma jeszcze żadnego pomiaru.
const _kDefaultWeightKg = 75.0;

/// Dziennik masy ciała: aktualna waga, cel z postępem i prognozą, trend
/// w okresie, wykres i pomiary pogrupowane w tygodnie. Wymaga
/// [BodyWeightCubit] w kontekście.
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

  Future<void> _editGoal() async {
    final cubit = context.read<BodyWeightCubit>();
    final input = await showBodyWeightGoalSheet(
      context,
      initialKg: cubit.state.latest?.weightKg ?? _kDefaultWeightKg,
      currentGoalKg: cubit.state.goalKg,
    );
    if (input == null || input.kg == cubit.state.goalKg) return;
    await cubit.saveGoal(input.kg);
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
              margin: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                kBodyWeightAddBarHeight - 40,
              ),
            ),
          );
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            const _Glow(),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  AppHeader(
                    title: 'Masa ciała',
                    height: AppSpacing.minTapTarget,
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    onBack: () => context.pop(),
                    actions: [
                      AppHeaderIconButton(
                        key: bodyWeightMeasurementsButtonKey,
                        icon: Icons.straighten_rounded,
                        tooltip: 'Pomiary ciała',
                        onTap: () => context.push(kBodyMeasurementsRoute),
                      ),
                    ],
                  ),
                  Expanded(child: _body()),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BlocBuilder<BodyWeightCubit, BodyWeightState>(
                buildWhen: (previous, current) =>
                    (previous.entries == null) != (current.entries == null) ||
                    previous.saving != current.saving,
                builder: (context, state) {
                  if (state.entries == null) return const SizedBox.shrink();
                  return BodyWeightAddButton(
                    key: bodyWeightAddButtonKey,
                    saving: state.saving,
                    onPressed: _addEntry,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    return BlocBuilder<BodyWeightCubit, BodyWeightState>(
      builder: (context, state) {
        final cubit = context.read<BodyWeightCubit>();
        final entries = state.entries;
        if (entries == null) {
          if (state.loadError != null) {
            return _LoadError(message: state.loadError!, onRetry: cubit.load);
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
                  onEditGoal: _editGoal,
                  onEntryTap: _editEntry,
                  onEntryMore: _showEntryActions,
                ),
        );
      },
    );
  }
}

enum _EntryAction { edit, delete }

/// Poświata w kolorze trendu w prawym górnym rogu.
class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: -120,
      top: -140,
      width: 420,
      height: 340,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppColors.statTeal.withValues(alpha: 0.14),
                AppColors.statTeal.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.state,
    required this.today,
    required this.onRangeChanged,
    required this.onEditGoal,
    required this.onEntryTap,
    required this.onEntryMore,
  });

  final BodyWeightState state;
  final DateTime today;
  final ValueChanged<BodyWeightRange> onRangeChanged;
  final VoidCallback onEditGoal;
  final ValueChanged<BodyWeightEntry> onEntryTap;
  final ValueChanged<BodyWeightEntry> onEntryMore;

  @override
  Widget build(BuildContext context) {
    final entries = state.entries!;
    final latest = entries.last;
    final trendKg = bodyWeightSmoothedTrend(entries);
    final average = bodyWeightRecentAverage(entries)!;
    final start = state.range.startFor(today);
    final firstInRange = start == null
        ? 0
        : entries.indexWhere((e) => !e.date.isBefore(start));
    final inRange = firstInRange < 0
        ? const <BodyWeightEntry>[]
        : entries.sublist(firstInRange);
    final goalKg = state.goalKg;
    final goal = goalKg == null
        ? null
        : BodyWeightGoalProgress(
            startKg: entries.first.weightKg,
            currentKg: latest.weightKg,
            goalKg: goalKg,
          );
    final pace = bodyWeightWeeklyPace(entries);
    final goalDate = goal == null || goal.reached
        ? null
        : bodyWeightGoalDate(
            fromKg: average,
            goalKg: goal.goalKg,
            pacePerWeekKg: pace,
            from: latest.date,
          );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        14,
        AppSpacing.pageGutter,
        kBodyWeightAddBarHeight + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        BodyWeightCurrentSection(
          latest: latest,
          trend: bodyWeightTrend(inRange),
          today: today,
          goal: goal,
        ),
        if (state.goalLoaded) ...[
          const SizedBox(height: AppSpacing.sm),
          if (goal != null)
            BodyWeightGoalCard(progress: goal, onTap: onEditGoal)
          else
            BodyWeightGoalCta(onTap: onEditGoal),
        ],
        const SizedBox(height: 10),
        BodyWeightStatTiles(
          averageKg: average,
          pacePerWeekKg: pace,
          paceTowardGoal: pace != null && (goal?.isTowardGoal(pace) ?? false),
          goalDate: goalDate,
          today: today,
        ),
        const SizedBox(height: 14),
        BodyWeightRangeTabs(selected: state.range, onChanged: onRangeChanged),
        const SizedBox(height: 10),
        BodyWeightChartCard(
          // Nowy okres rysuje linię od nowa.
          key: ValueKey(state.range),
          entries: inRange,
          trendKg: firstInRange < 0 ? const [] : trendKg.sublist(firstInRange),
          goalKg: goalKg,
        ),
        const SizedBox(height: 14),
        BodyWeightWeekList(
          weeks: bodyWeightWeeks(entries),
          goal: goal,
          onEntryTap: onEntryTap,
          onEntryMore: onEntryMore,
        ),
      ],
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
