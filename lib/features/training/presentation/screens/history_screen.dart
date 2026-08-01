import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/workout_history_cubit.dart';
import '../widgets/training_header.dart';
import '../widgets/workout_history/month_selector_bar.dart';
import '../widgets/workout_history/monthly_sessions_list.dart';
import '../widgets/workout_history/monthly_stats_card.dart';
import '../widgets/workout_history/monthly_summary_footer.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WorkoutHistoryCubit(ServiceLocator.trainingHistoryRepository),
      child: const _WorkoutHistoryView(),
    );
  }
}

class _WorkoutHistoryView extends StatefulWidget {
  const _WorkoutHistoryView();

  @override
  State<_WorkoutHistoryView> createState() => _WorkoutHistoryViewState();
}

class _WorkoutHistoryViewState extends State<_WorkoutHistoryView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh(BuildContext context) async {
    HapticFeedback.lightImpact();
    await context.read<WorkoutHistoryCubit>().refresh();
  }

  void _onHorizontalDragEnd(BuildContext context, DragEndDetails details, WorkoutHistoryState state) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 200) return;

    final currentIndex = state.availableMonths.indexWhere(
      (m) => m.year == state.focusedMonth.year && m.month == state.focusedMonth.month,
    );
    if (currentIndex == -1) return;

    if (velocity < 0) {
      // Swiped left -> next month
      if (currentIndex < state.availableMonths.length - 1) {
        context.read<WorkoutHistoryCubit>().selectMonth(state.availableMonths[currentIndex + 1]);
      }
    } else {
      // Swiped right -> previous month
      if (currentIndex > 0) {
        context.read<WorkoutHistoryCubit>().selectMonth(state.availableMonths[currentIndex - 1]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocBuilder<WorkoutHistoryCubit, WorkoutHistoryState>(
          builder: (context, state) {
            final cubit = context.read<WorkoutHistoryCubit>();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header (W stylu panelu Plany / Trening)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Historia',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Twoje zakończone treningi',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      HeaderIconButton(
                        tooltip: 'Wybierz rok/miesiąc',
                        icon: Icons.calendar_today_rounded,
                        onTap: () => cubit.openMonthPicker(context),
                      ),
                    ],
                  ),
                ),

                // 2. Month Selector Bar
                const SizedBox(height: 16),
                MonthSelectorBar(
                  availableMonths: state.availableMonths,
                  focusedMonth: state.focusedMonth,
                  onMonthSelected: (month) => cubit.selectMonth(month),
                ),
                const SizedBox(height: 12),

                // Main Content — Vertical scroll view with swipe gesture for months
                Expanded(
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) => _onHorizontalDragEnd(context, details, state),
                    behavior: HitTestBehavior.opaque,
                    child: RefreshIndicator(
                      onRefresh: () => _onRefresh(context),
                      color: AppColors.primary,
                      child: _buildBody(context, state, cubit),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WorkoutHistoryState state, WorkoutHistoryCubit cubit) {
    if (state.isLoading) {
      return const _WorkoutHistorySkeleton();
    }

    if (state.error != null && state.monthlyHistory == null) {
      return _WorkoutHistoryError(
        message: state.error!,
        onRetry: () => cubit.refresh(),
      );
    }

    final history = state.monthlyHistory;
    final stats = history?.stats;
    final sessions = state.filteredSessions;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.fromCache)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                'Tryb offline: pokazujemy zapisane dane z pamięci podręcznej.',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),

          // Subtitle indicator if month changing in background
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: state.isMonthChanging
                ? const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // 3. Monthly Stats Card
          if (stats != null) ...[
            MonthlyStatsCard(
              focusedMonth: state.focusedMonth,
              stats: stats,
            ),
            const SizedBox(height: 16),
          ],

          // 5. Recent Sessions List
          MonthlySessionsList(
            sessions: sessions,
            selectedDay: state.selectedDay,
          ),

          // 6. Monthly Summary Footer
          if (stats != null) ...[
            const SizedBox(height: 20),
            MonthlySummaryFooter(stats: stats),
          ],
        ],
      ),
    );
  }
}

class _WorkoutHistorySkeleton extends StatelessWidget {
  const _WorkoutHistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        Container(
          height: 170,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 190,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ],
    );
  }
}

class _WorkoutHistoryError extends StatelessWidget {
  const _WorkoutHistoryError({
    required this.message,
    required this.onRetry,
  });

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
              Icons.wifi_off_rounded,
              color: AppColors.textMuted,
              size: 36,
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
