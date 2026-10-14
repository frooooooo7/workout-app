import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/plan_icons.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../../core/widgets/app_pressable.dart';
import '../../../domain/models/training_history_models.dart';
import '../session_details/session_details_formatters.dart';
import 'history_formatters.dart';
import 'history_plan_style.dart';

/// Wiersz sesji w Historii: odznaka z kolorem i literą planu, nazwa planu
/// (z odznaką rekordów, jeśli padły), data · godzina · czas w jednej linii
/// i tonaż jako główna liczba. Stuknięcie otwiera szczegóły sesji.
class HistorySessionRow extends StatelessWidget {
  const HistorySessionRow({
    super.key,
    required this.session,
    this.recordsCount = 0,
  });

  final TrainingSessionListItem session;

  /// Rekordy pobite w tej sesji.
  final int recordsCount;

  @override
  Widget build(BuildContext context) {
    final plan = HistoryPlanStyle.of(session);
    final sets = session.completedSetsCount;

    return AppPressable(
      onTap: () => context.push('/app/training/history/${session.id}'),
      pressedScale: 0.98,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            PlanBadge(
              name: plan.name,
              color: plan.color,
              iconKey: plan.iconKey,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          plan.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (recordsCount > 0) ...[
                        const SizedBox(width: AppSpacing.xs),
                        _RecordBadge(count: recordsCount),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${formatSessionDay(session.startedAt)} · '
                    '${formatClock(session.startedAt)} · '
                    '${formatHoursMinutes(session.durationSec)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatVolumeKg(session.totalVolumeKg ?? 0),
                  style: AppTextStyles.number(size: 21),
                ),
                const SizedBox(height: 3),
                Text(
                  '$sets ${polishPlural(sets, 'seria', 'serie', 'serii')}',
                  style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Złota pigułka „rekord” / „2 rekordy”.
class _RecordBadge extends StatelessWidget {
  const _RecordBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1
        ? 'rekord'
        : '$count ${polishPlural(count, 'rekord', 'rekordy', 'rekordów')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.record.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_outlined,
            size: 12,
            color: AppColors.record,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.record,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
