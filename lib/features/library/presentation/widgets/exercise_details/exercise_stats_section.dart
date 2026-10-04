import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../../core/widgets/skeleton.dart';
import '../../../../training/presentation/widgets/session_details/session_details_formatters.dart';
import '../../../domain/models/exercise_stats.dart';
import 'exercise_progress_chart.dart';

/// „Twoje wyniki”: rekordy, liczniki i wykres progresu z historii treningów.
class ExerciseStatsSection extends StatelessWidget {
  const ExerciseStatsSection({super.key, required this.stats});

  /// `null` — wyniki jeszcze się liczą.
  final ExerciseStats? stats;

  @override
  Widget build(BuildContext context) {
    final stats = this.stats;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      child: switch (stats) {
        null => const _StatsSkeleton(key: ValueKey('loading')),
        final s when !s.hasData => const _StatsEmpty(key: ValueKey('empty')),
        final s => _StatsContent(key: const ValueKey('content'), stats: s),
      },
    );
  }
}

class _StatsContent extends StatelessWidget {
  const _StatsContent({super.key, required this.stats});

  final ExerciseStats stats;

  @override
  Widget build(BuildContext context) {
    final record = stats.hasWeights
        ? _StatTile(
            label: 'Rekord',
            value: formatWeight(stats.bestWeightKg!),
            unit: 'kg',
            caption: stats.bestWeightReps == null
                ? null
                : '× ${stats.bestWeightReps} '
                      '${polishPlural(stats.bestWeightReps!, 'powtórzenie', 'powtórzenia', 'powtórzeń')}',
            icon: Icons.emoji_events_rounded,
            accent: const Color(0xFFF59E0B),
          )
        : _StatTile(
            label: 'Najwięcej powt.',
            value: '${stats.maxReps ?? 0}',
            unit: 'powt.',
            caption: 'w jednej serii',
            icon: Icons.emoji_events_rounded,
            accent: const Color(0xFFF59E0B),
          );

    final oneRm = stats.bestEstimatedOneRepMaxKg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: record),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: 'Szac. 1RM',
                value: oneRm == null ? '—' : formatWeight(_roundHalf(oneRm)),
                unit: oneRm == null ? null : 'kg',
                caption: 'wzór Epleya',
                icon: Icons.bolt_rounded,
                accent: AppColors.primaryVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Treningi',
                value: '${stats.sessionsCount}',
                caption:
                    '${stats.totalSets} ${polishPlural(stats.totalSets, 'seria', 'serie', 'serii')}',
                icon: Icons.event_repeat_rounded,
                accent: AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: 'Objętość',
                value: formatVolumeKg(stats.totalVolumeKg),
                caption: 'łącznie',
                icon: Icons.stacked_bar_chart_rounded,
                accent: const Color(0xFF4DB6AC),
              ),
            ),
          ],
        ),
        if (stats.history.length >= 2) ...[
          const SizedBox(height: 18),
          ExerciseProgressChart(stats: stats),
        ],
        if (stats.lastPerformedAt != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 15,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                'Ostatnio: ${formatExerciseHistoryDate(stats.lastPerformedAt!)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static double _roundHalf(double value) => (value * 2).round() / 2;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.unit,
    this.caption,
  });

  final String label;
  final String value;
  final String? unit;
  final String? caption;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.1),
            AppColors.surfaceVariant.withValues(alpha: 0.35),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 3),
                  Text(
                    unit!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 3),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsEmpty extends StatelessWidget {
  const _StatsEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: AppColors.primaryVariant,
              size: 22,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Brak wyników',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Zrób to ćwiczenie na treningu, a tutaj pojawią się '
            'Twoje rekordy i wykres progresu.',
            textAlign: TextAlign.center,
            style: TextStyle(
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

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      label: 'Ładowanie wyników',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: SkeletonBlock(height: 86, radius: 14)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBlock(height: 86, radius: 14)),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: SkeletonBlock(height: 86, radius: 14)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBlock(height: 86, radius: 14)),
            ],
          ),
        ],
      ),
    );
  }
}
