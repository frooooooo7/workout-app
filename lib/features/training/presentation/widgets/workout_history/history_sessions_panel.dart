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
import 'history_feed_list.dart';
import 'history_latest_card.dart';

/// Pierwszy panel Historii: karta „Ostatni trening” i pod nią „Wcześniej” —
/// jedna karta na miesiąc ze zwartymi wierszami. Kalendarz otwiera się osobno,
/// z ikonki w nagłówku; do wskazanego w nim dnia panel przewija przez
/// [HistorySessionsPanelState.showDay].
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

  DateTime? _highlightedDay;
  Timer? _highlightTimer;

  // Podział listy liczymy raz na zmianę danych, nie przy każdej przebudowie.
  List<HistoryFeedEntry>? _sectionsFor;
  List<HistoryMonthSection> _sections = const [];

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _dayKey(DateTime day) =>
      _dayKeys.putIfAbsent(day, () => GlobalKey(debugLabel: 'day-$day'));

  void _group(HistoryFeedState state) {
    if (identical(state.entries, _sectionsFor)) return;
    _sectionsFor = state.entries;
    _sections = groupHistoryFeed(
      state.entries,
      exceptId: state.latest?.entry.item.id,
    );
  }

  /// Przewija listę do [day] i podświetla go na chwilę. Dzień ostatniego
  /// treningu to góra listy, a tam stoi jego karta.
  Future<void> showDay(DateTime day) async {
    final target = DateTime(day.year, day.month, day.day);
    final state = context.read<HistoryFeedCubit>().state;
    if (!state.entries.any((entry) => entry.day == target)) return;

    final index = _rowIndexOf(target);
    if (state.latest?.entry.day == target || index == null) {
      if (_scroll.hasClients) {
        await _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      await _scrollToRow(target, index);
    }
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
      for (final entry in section.rows) {
        if (entry.day == day) return index;
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
          alignment: 0.2,
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
    _group(state);
    final latest = state.latest;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                if (latest == null)
                  const SliverToBoxAdapter(child: _EmptyHistory())
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageGutter,
                      AppSpacing.xxs,
                      AppSpacing.pageGutter,
                      AppSpacing.xs,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: HistoryLatestCard(
                        latest: latest,
                        today: today,
                        highlighted: latest.entry.day == _highlightedDay,
                      ),
                    ),
                  ),
                  if (_sections.isNotEmpty)
                    HistoryFeedSliver(
                      sections: _sections,
                      today: today,
                      dayKeyFor: _dayKey,
                      highlightedDay: _highlightedDay,
                      onRowMounted: _builtRows.add,
                      onRowUnmounted: _builtRows.remove,
                    ),
                ],
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

/// Szkielet pierwszego wczytania: karta ostatniego treningu i kilka wierszy.
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
        children: const [
          SkeletonBlock(height: 330, radius: 24),
          SizedBox(height: AppSpacing.md),
          SkeletonBlock(width: 160, height: 16),
          SizedBox(height: AppSpacing.sm),
          SkeletonBlock(height: 66 * 3, radius: 22),
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
