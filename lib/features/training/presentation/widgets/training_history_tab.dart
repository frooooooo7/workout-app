import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/training_history_models.dart';
import '../bloc/training_history_cubit.dart';
import 'training_history_calendar_view.dart';
import 'training_history_filters_bar.dart';
import 'training_history_session_card.dart';

class TrainingHistoryTab extends StatelessWidget {
  const TrainingHistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          TrainingHistoryCubit(ServiceLocator.trainingHistoryRepository),
      child: const _TrainingHistoryView(),
    );
  }
}

class _TrainingHistoryView extends StatefulWidget {
  const _TrainingHistoryView();

  @override
  State<_TrainingHistoryView> createState() => _TrainingHistoryViewState();
}

class _TrainingHistoryViewState extends State<_TrainingHistoryView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.extentAfter < 400) {
      context.read<TrainingHistoryCubit>().loadMore();
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    await context.read<TrainingHistoryCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainingHistoryCubit, TrainingHistoryState>(
      builder: (context, state) {
        if (state.loading) {
          return const _LoadingSkeleton();
        }
        if (state.error != null && state.items.isEmpty && state.calendarSessions.isEmpty) {
          return _ErrorState(
            message: state.error!,
            onRetry: () => context.read<TrainingHistoryCubit>().retry(),
          );
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _HistoryFiltersHeaderDelegate(
                  child: TrainingHistoryFiltersBar(state: state),
                ),
              ),
              if (state.fromCache)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Text(
                      'Tryb offline: pokazujemy ostatnio zapisane sesje.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              if (state.viewMode == HistoryViewMode.calendar) ...[
                SliverToBoxAdapter(
                  child: TrainingHistoryCalendarView(state: state),
                ),
              ] else if (state.items.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: _EmptyState(
                      icon: Icons.history_rounded,
                      title: 'Brak historii',
                      subtitle:
                          'Rozpocznij pierwszy trening, aby zobaczyć sesje.',
                      ctaLabel: 'Rozpocznij pierwszy trening',
                      onTap: () =>
                          context.push('/app/training/pick-activity-type'),
                    ),
                  ),
                )
              else ...[
                ..._buildSections(state.items),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                    child: _LoadMoreFooter(state: state),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildSections(List<TrainingSessionListItem> items) {
    final groups = <String, List<TrainingSessionListItem>>{};
    for (final item in items) {
      final key = _groupLabel(item.startedAt);
      groups.putIfAbsent(key, () => []).add(item);
    }
    final sections = <Widget>[];
    groups.forEach((label, groupedItems) {
      sections.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
      sections.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                for (var index = 0; index < groupedItems.length; index++) ...[
                  TrainingHistorySessionCard(
                    item: groupedItems[index],
                    onTap: () => context.push(
                      '/app/training/history/${groupedItems[index].id}',
                    ),
                  ),
                  if (index < groupedItems.length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      );
    });
    return sections;
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.state});

  final TrainingHistoryState state;

  @override
  Widget build(BuildContext context) {
    if (state.loadingMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.2,
          ),
        ),
      );
    }
    if (!state.hasMore) {
      return const SizedBox.shrink();
    }
    return Center(
      child: OutlinedButton(
        onPressed: () => context.read<TrainingHistoryCubit>().loadMore(),
        child: const Text('Załaduj starsze'),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      children: [
        Row(
          children: const [
            Expanded(child: _SkeletonBox(height: 44)),
            SizedBox(width: 12),
            _SkeletonBox(height: 44, width: 44),
            SizedBox(width: 12),
            _SkeletonBox(height: 44, width: 44),
          ],
        ),
        const SizedBox(height: 16),
        ...List.generate(
          4,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: _SkeletonBox(height: 98),
          ),
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

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
              size: 34,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.textMuted, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: onTap, child: Text(ctaLabel)),
        ],
      ),
    );
  }
}

class _HistoryFiltersHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _HistoryFiltersHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 70;

  @override
  double get maxExtent => 70;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _HistoryFiltersHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

String _groupLabel(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(local.year, local.month, local.day);
  final diffDays = today.difference(target).inDays;
  if (diffDays == 0) return 'Dziś';
  if (diffDays == 1) return 'Wczoraj';
  return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
}
