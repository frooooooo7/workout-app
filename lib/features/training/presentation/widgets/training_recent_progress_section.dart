import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../domain/models/training_history_models.dart';
import '../bloc/training_history_cubit.dart';

class TrainingRecentProgressSection extends StatelessWidget {
  const TrainingRecentProgressSection({
    super.key,
    required this.state,
    required this.onOpenSession,
  });

  final TrainingHistoryState state;
  final ValueChanged<TrainingSessionListItem> onOpenSession;

  @override
  Widget build(BuildContext context) {
    final items = state.items.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ostatnie postepy',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (state.loading && items.isEmpty)
          const _RecentProgressSkeleton()
        else if (state.error != null && items.isEmpty)
          const _RecentProgressMessage(
            icon: Icons.wifi_off_rounded,
            message: 'Nie udalo sie zaladowac ostatnich postepow.',
          )
        else if (items.isEmpty)
          const _RecentProgressMessage(
            icon: Icons.emoji_events_outlined,
            message: 'Ukoncz pierwszy trening, a tutaj zobaczysz postepy.',
          )
        else
          Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                _RecentProgressCard(
                  item: items[index],
                  onTap: () => onOpenSession(items[index]),
                ),
                if (index < items.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
      ],
    );
  }
}

class _RecentProgressCard extends StatelessWidget {
  const _RecentProgressCard({required this.item, required this.onTap});

  final TrainingSessionListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlight = item.progressHighlight;
    final details =
        '${formatDuration(item.durationSec)} - ${item.exercisesCount} cw. - '
        '${item.completedSetsCount} serii';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _highlightColor(highlight).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _highlightIcon(highlight),
                color: _highlightColor(highlight),
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.plan.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    highlight?.label ?? 'Brak progresu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: highlight == null
                          ? AppColors.textMuted
                          : AppColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Color _highlightColor(TrainingProgressHighlight? highlight) {
    return switch (highlight?.type) {
      TrainingProgressHighlightType.weightIncrease => AppColors.primary,
      TrainingProgressHighlightType.volumeIncrease => AppColors.success,
      TrainingProgressHighlightType.noProgress => AppColors.textMuted,
      null => AppColors.textMuted,
    };
  }

  IconData _highlightIcon(TrainingProgressHighlight? highlight) {
    return switch (highlight?.type) {
      TrainingProgressHighlightType.weightIncrease =>
        Icons.trending_up_rounded,
      TrainingProgressHighlightType.volumeIncrease =>
        Icons.show_chart_rounded,
      TrainingProgressHighlightType.noProgress => Icons.remove_rounded,
      null => Icons.history_rounded,
    };
  }
}

class _RecentProgressSkeleton extends StatelessWidget {
  const _RecentProgressSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 8),
          child: Container(
            height: 78,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentProgressMessage extends StatelessWidget {
  const _RecentProgressMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 26),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
