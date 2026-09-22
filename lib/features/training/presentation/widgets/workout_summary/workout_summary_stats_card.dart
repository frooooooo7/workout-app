import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../domain/models/training_history_models.dart';
import '../session_details/session_details_formatters.dart';

/// Kluczowe liczby sesji w jednej karcie: czas, objętość, serie i pasek
/// ukończenia planu. Jedyne miejsce na ekranie z metrykami całej sesji.
class WorkoutSummaryStatsCard extends StatelessWidget {
  const WorkoutSummaryStatsCard({super.key, required this.detail});

  final TrainingSessionDetail detail;

  @override
  Widget build(BuildContext context) {
    final completed = detail.completedSetsCount;
    final planned = detail.exercises.fold(0, (sum, e) => sum + e.sets.length);
    final ratio = planned == 0 ? 0.0 : completed / planned;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: formatDigitalDuration(detail.durationSec),
                    label: 'Czas',
                  ),
                ),
                const _StatDivider(),
                Expanded(
                  child: _Stat(
                    value: formatVolumeKg(detail.totalVolumeKg),
                    label: 'Objętość',
                  ),
                ),
                const _StatDivider(),
                Expanded(
                  child: _Stat(value: '$completed', label: 'Ukończone serie'),
                ),
              ],
            ),
          ),
          if (planned > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            _CompletionBar(
              completed: completed,
              planned: planned,
              ratio: ratio,
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      color: AppColors.border.withValues(alpha: 0.6),
    );
  }
}

class _CompletionBar extends StatelessWidget {
  const _CompletionBar({
    required this.completed,
    required this.planned,
    required this.ratio,
  });

  final int completed;
  final int planned;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final percent = (ratio * 100).round();
    final allDone = completed >= planned;

    return Semantics(
      label: 'Ukończono $completed z $planned serii, $percent procent',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                allDone ? Icons.verified_rounded : Icons.flag_rounded,
                size: 15,
                color: AppColors.success,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  allDone
                      ? 'Cały plan zrobiony'
                      : 'Ukończono $completed z $planned serii',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.8),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: ratio.clamp(0, 1)),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.success.withValues(alpha: 0.7),
                              AppColors.success,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
