import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/polish_plural.dart';
import '../../../training/domain/models/training_summary_stats.dart';
import '../../domain/services/profile_week_calculator.dart';

/// „Ten tydzień”: dni z treningiem (pon–nd), liczba treningów, czas,
/// objętość i seria tygodni. Tap otwiera pełne statystyki.
class ProfileWeekCard extends StatelessWidget {
  const ProfileWeekCard({
    super.key,
    required this.summary,
    this.onTap,
    this.now,
  });

  final ProfileWeekSummary summary;
  final VoidCallback? onTap;

  /// Test seam dla podświetlenia dzisiejszego dnia.
  final DateTime? now;

  static const _dayLabels = ['P', 'W', 'Ś', 'C', 'P', 'S', 'N'];

  @override
  Widget build(BuildContext context) {
    final today = (now ?? DateTime.now()).weekday;
    final stats = summary.stats;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('profile-week-card'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Ten tydzień',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (summary.streakWeeks > 0)
                      _StreakPill(weeks: summary.streakWeeks),
                    if (onTap != null) ...[
                      const SizedBox(width: AppSpacing.xxs),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var day = 1; day <= 7; day++)
                      _DayDot(
                        label: _dayLabels[day - 1],
                        trained: summary.trainedWeekdays.contains(day),
                        isToday: day == today,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  height: 1,
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: _Metric(
                        value: '${stats.workouts}',
                        label: polishPlural(
                          stats.workouts,
                          'trening',
                          'treningi',
                          'treningów',
                        ),
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        value: stats.durationSec == 0
                            ? '0 min'
                            : formatDuration(stats.durationSec),
                        label: 'czas',
                      ),
                    ),
                    Expanded(
                      child: _Metric(
                        value:
                            '${formatTrainingVolumeKg(stats.volumeKg.round())} kg',
                        label: 'objętość',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.weeks});

  final int weeks;

  @override
  Widget build(BuildContext context) {
    final capped = weeks >= ProfileWeekCalculator.streakLookbackWeeks;
    final count = capped ? '$weeks+' : '$weeks';
    final unit = polishPlural(weeks, 'tydzień', 'tygodnie', 'tygodni');
    return Semantics(
      label: 'Seria: $count $unit z rzędu z treningiem',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: AppColors.strengthMedium.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              size: 14,
              color: AppColors.strengthMedium,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              '$count ${capped ? 'tyg.' : unit}',
              style: const TextStyle(
                color: AppColors.strengthMedium,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.trained,
    required this.isToday,
  });

  final String label;
  final bool trained;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: trained ? AppColors.primary : AppColors.surfaceVariant,
            border: isToday
                ? Border.all(color: AppColors.primaryVariant, width: 2)
                : null,
          ),
          child: trained
              ? const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: AppColors.onPrimary,
                )
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isToday ? AppColors.textPrimary : AppColors.textMuted,
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
