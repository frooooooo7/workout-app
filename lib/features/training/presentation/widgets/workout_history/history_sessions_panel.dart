import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_tab_header.dart';
import '../../../../../core/widgets/skeleton.dart';
import '../../../domain/services/history_feed_builder.dart';
import '../../bloc/history_feed_cubit.dart';
import '../../bloc/training_stats_cubit.dart';
import 'history_feed_list.dart';
import 'history_filter_bar.dart';

/// Pierwszy panel Historii: filtry i ciągła lista treningów z ćwiczeniami.
/// Kalendarz otwiera się osobno, z ikonki w nagłówku; do wskazanego w nim dnia
/// panel przewija przez [HistorySessionsPanelState.showDay].
class HistorySessionsPanel extends StatefulWidget {
  const HistorySessionsPanel({super.key, required this.onRefresh});

  /// Przeciągnięcie listy w dół.
  final Future<void> Function() onRefresh;

  @override
  State<HistorySessionsPanel> createState() => HistorySessionsPanelState();
}

class HistorySessionsPanelState extends State<HistorySessionsPanel> {
  final _scroll = ScrollController();
  final _dayKeys = <DateTime, GlobalKey>{};
  final _builtRows = <int>{};

  HistoryFilter _filter = HistoryFilter.all;
  DateTime? _highlightedDay;
  Timer? _highlightTimer;

  // Podział listy liczymy raz na zmianę danych albo filtra, nie przy każdej
  // przebudowie.
  List<HistoryFeedEntry>? _sectionsFor;
  HistoryFilter? _sectionsFilter;
  List<HistoryMonthSection> _sections = const [];
  Map<DateTime, int> _weekCounts = const {};

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _dayKey(DateTime day) =>
      _dayKeys.putIfAbsent(day, () => GlobalKey(debugLabel: 'day-$day'));

  void _group(List<HistoryFeedEntry> entries, HistoryFilter filter) {
    if (identical(entries, _sectionsFor) && filter == _sectionsFilter) return;
    _sectionsFor = entries;
    _sectionsFilter = filter;
    _weekCounts = workoutsPerWeek(entries);
    _sections = groupHistoryFeed([
      for (final entry in entries)
        if (filter.matches(entry)) entry,
    ]);
  }

  /// Przewija listę do [day] i podświetla go na chwilę. Filtr, który ukrywa
  /// ten dzień, wraca do „Wszystkie”.
  Future<void> showDay(DateTime day) async {
    final target = DateTime(day.year, day.month, day.day);
    final entries = context.read<HistoryFeedCubit>().state.entries;
    final dayEntries = [
      for (final entry in entries)
        if (entry.day == target) entry,
    ];
    if (dayEntries.isEmpty) return;
    if (!dayEntries.any(_filter.matches)) {
      setState(() => _filter = HistoryFilter.all);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    final index = _rowIndexOf(target);
    if (index == null) return;
    await _scrollToRow(target, index);
    if (!mounted) return;
    _highlightTimer?.cancel();
    setState(() => _highlightedDay = target);
    _highlightTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _highlightedDay = null);
    });
  }

  int? _rowIndexOf(DateTime day) {
    var index = 0;
    for (final section in _sections) {
      for (final row in section.rows) {
        if (row is HistoryDayRow && row.day == day) return index;
        index++;
      }
    }
    return null;
  }

  int get _rowCount =>
      _sections.fold(0, (sum, section) => sum + section.rows.length);

  /// Wiersze budują się leniwie, więc dnia z dalekiego miesiąca jeszcze nie
  /// ma w drzewie. Skaczemy na oko (proporcja numeru wiersza do całości),
  /// a potem krokami w stronę celu, aż się zbuduje — wtedy dopiero dokładne
  /// przewinięcie.
  Future<void> _scrollToRow(DateTime day, int targetIndex) async {
    for (var attempt = 0; attempt < 60; attempt++) {
      if (!mounted || !_scroll.hasClients) return;
      final context = _dayKeys[day]?.currentContext;
      if (context != null && context.mounted) {
        await Scrollable.ensureVisible(
          context,
          alignment: 0.12,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      if (_builtRows.isEmpty) return;
      final position = _scroll.position;
      final first = _builtRows.reduce(math.min);
      final double next;
      if (attempt == 0 && _rowCount > 1) {
        next = position.maxScrollExtent * targetIndex / (_rowCount - 1);
      } else if (targetIndex < first) {
        next = position.pixels - position.viewportDimension * 0.8;
      } else {
        next = position.pixels + position.viewportDimension * 0.8;
      }
      position.jumpTo(
        next.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  HistoryFilter _effectiveFilter(
    bool showFilters,
    List<HistoryPlanOption> plans,
    bool hasRecords,
  ) {
    final filter = _filter;
    if (!showFilters || filter == HistoryFilter.all) return HistoryFilter.all;
    if (filter == HistoryFilter.records) {
      return hasRecords ? filter : HistoryFilter.all;
    }
    return plans.any((p) => HistoryFilter.plan(p.key) == filter)
        ? filter
        : HistoryFilter.all;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HistoryFeedCubit, HistoryFeedState>(
      builder: (context, state) {
        if (state.loading) return const _HistorySkeleton();
        if (state.failed) {
          return _HistoryError(
            onRetry: () => context.read<HistoryFeedCubit>().load(),
          );
        }
        return _buildLoaded(context, state);
      },
    );
  }

  Widget _buildLoaded(BuildContext context, HistoryFeedState state) {
    final plans = historyPlanOptions(state.entries);
    final hasRecords = state.entries.any((e) => e.recordsCount > 0);
    final showFilters = HistoryFilterBar.isUseful(
      plans: plans.length,
      hasRecords: hasRecords,
    );

    // Filtr, którego już nie ma w danych (plan zniknął po synchronizacji),
    // nie może zostawić pustej listy.
    final filter = _effectiveFilter(showFilters, plans, hasRecords);
    _group(state.entries, filter);

    final goal = context.select(
      (TrainingStatsCubit c) => c.state.snapshot?.goal?.goal,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showFilters) ...[
          const SizedBox(height: AppSpacing.xs),
          HistoryFilterBar(
            plans: plans,
            hasRecords: hasRecords,
            selected: filter,
            onSelected: (selected) => setState(() => _filter = selected),
          ),
          const SizedBox(height: AppSpacing.xs),
        ] else
          const SizedBox(height: AppSpacing.xs),
        const AppTabScrollEdge(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            color: AppColors.primary,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (state.entries.isEmpty)
                  const SliverToBoxAdapter(child: _EmptyHistory())
                else if (_sections.isEmpty)
                  SliverToBoxAdapter(
                    child: _EmptyFilter(
                      onShowAll: () =>
                          setState(() => _filter = HistoryFilter.all),
                    ),
                  )
                else
                  HistoryFeedSliver(
                    sections: _sections,
                    today: today,
                    dayKeyFor: _dayKey,
                    weekCounts: _weekCounts,
                    // Licznik celu dotyczy całego tygodnia — przy filtrze
                    // planu pokazywałby tylko jego część.
                    weeklyGoal: filter == HistoryFilter.all ? goal : null,
                    highlightedDay: _highlightedDay,
                    onRowMounted: _builtRows.add,
                    onRowUnmounted: _builtRows.remove,
                  ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height:
                        AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Szkielet pierwszego wczytania: filtry i kilka kart.
class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      label: 'Wczytywanie historii',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xs + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Row(
            children: const [
              SkeletonBlock(width: 96, height: 40, radius: 20),
              SizedBox(width: AppSpacing.xs),
              SkeletonBlock(width: 72, height: 40, radius: 20),
              SizedBox(width: AppSpacing.xs),
              SkeletonBlock(width: 72, height: 40, radius: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const SkeletonBlock(width: 160, height: 16),
          for (var i = 0; i < 3; i++) ...[
            const SizedBox(height: AppSpacing.sm),
            const SkeletonBlock(height: 150, radius: 22),
          ],
        ],
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.onRetry});

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
              Icons.wifi_off_rounded,
              color: AppColors.textMuted,
              size: 36,
            ),
            const SizedBox(height: 14),
            const Text(
              'Nie udało się pobrać historii treningów. '
              'Sprawdź połączenie i spróbuj ponownie.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xl,
        horizontal: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 28),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryVariant,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return _EmptyCard(
      icon: Icons.fitness_center_rounded,
      message: 'Brak zarejestrowanych treningów',
      actionLabel: 'Zacznij trening',
      onAction: () => context.go('/app/training'),
    );
  }
}

class _EmptyFilter extends StatelessWidget {
  const _EmptyFilter({required this.onShowAll});

  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return _EmptyCard(
      icon: Icons.filter_alt_off_rounded,
      message: 'Brak treningów dla tego filtra',
      actionLabel: 'Pokaż wszystkie',
      onAction: onShowAll,
    );
  }
}
