import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../domain/models/training_history_models.dart';
import '../bloc/training_history_cubit.dart';

class TrainingLastSessionSection extends StatelessWidget {
  const TrainingLastSessionSection({
    super.key,
    required this.state,
    required this.onOpenDetails,
    required this.onRepeat,
  });

  final TrainingHistoryState state;
  final ValueChanged<TrainingSessionListItem> onOpenDetails;
  final ValueChanged<TrainingSessionListItem> onRepeat;

  @override
  Widget build(BuildContext context) {
    final item = state.items.isEmpty ? null : state.items.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ostatni trening',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (state.loading && item == null)
          const _LastSessionSkeleton()
        else if (state.error != null && item == null)
          const _LastSessionMessage(
            icon: Icons.wifi_off_rounded,
            message: 'Nie udało się załadować ostatniego treningu.',
          )
        else if (item == null)
          const _LastSessionMessage(
            icon: Icons.emoji_events_outlined,
            message: 'Ukończ pierwszy trening, a tutaj go zobaczysz.',
          )
        else
          _LastSessionCard(
            item: item,
            onOpenDetails: () => onOpenDetails(item),
            onRepeat: () => onRepeat(item),
          ),
      ],
    );
  }
}

class _LastSessionCard extends StatelessWidget {
  const _LastSessionCard({
    required this.item,
    required this.onOpenDetails,
    required this.onRepeat,
  });

  final TrainingSessionListItem item;
  final VoidCallback onOpenDetails;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    final highlight = item.progressHighlight;
    final details =
        '${formatDuration(item.durationSec)} · ${item.exercisesCount} ćw. · '
        '${item.completedSetsCount} serii';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'OSTATNI TRENING',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Text(
                relativeTrainingDayLabel(item.startedAt),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.plan.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            details,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (highlight != null) ...[
            const SizedBox(height: 8),
            Text(
              highlight.label,
              style: TextStyle(
                color: highlight.type == TrainingProgressHighlightType.noProgress
                    ? AppColors.textMuted
                    : AppColors.success,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const ValueKey('last-session-repeat'),
                  onPressed: onRepeat,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Powtórz',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('last-session-details'),
                  onPressed: onOpenDetails,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Szczegóły',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String relativeTrainingDayLabel(DateTime startedAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final local = startedAt.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'Dzisiaj';
  if (diff == 1) return 'Wczoraj';
  if (diff < 7) return '$diff dni temu';
  return '${local.day}.${local.month.toString().padLeft(2, '0')}';
}

class _LastSessionSkeleton extends StatelessWidget {
  const _LastSessionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
    );
  }
}

class _LastSessionMessage extends StatelessWidget {
  const _LastSessionMessage({required this.icon, required this.message});

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
