import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../domain/models/training_stats.dart';
import 'stats_format.dart';

/// Sześć kluczowych liczb zakresu, każda ze zmianą względem poprzedniego
/// okresu (albo z podpisem, gdy porównania nie ma).
class StatsKpiGrid extends StatelessWidget {
  const StatsKpiGrid({super.key, required this.snapshot});

  final TrainingStatsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final current = s.current;
    final previous = s.previous;
    final workouts = current.workouts;
    final volume = formatStatsVolume(current.volumeKg);
    final duration = formatStatsDuration(current.durationSec);

    String? perWorkout(String Function(double avg) format, num total) =>
        workouts == 0 ? null : 'śr. ${format(total / workouts)} / trening';

    final tiles = [
      StatsKpiTile(
        icon: Icons.fitness_center_rounded,
        color: AppColors.primaryVariant,
        label: 'Treningi',
        value: '$workouts',
        unit: '',
        delta: previous == null
            ? null
            : StatsDelta.absolute(workouts, previous.workouts),
        caption:
            '${s.trainingDays} ${polishPlural(s.trainingDays, 'dzień', 'dni', 'dni')} z treningiem',
      ),
      StatsKpiTile(
        icon: Icons.monitor_weight_outlined,
        color: AppColors.statIndigo,
        label: 'Objętość',
        value: volume.value,
        unit: volume.unit,
        delta: previous == null
            ? null
            : StatsDelta.percent(current.volumeKg, previous.volumeKg),
        caption: perWorkout((avg) {
          final v = formatStatsVolume(avg);
          return '${v.value} ${v.unit}';
        }, current.volumeKg),
      ),
      StatsKpiTile(
        icon: Icons.timer_outlined,
        color: AppColors.statOrange,
        label: 'Czas',
        value: duration.value,
        unit: duration.unit,
        delta: previous == null
            ? null
            : StatsDelta.percent(current.durationSec, previous.durationSec),
        caption: perWorkout(
          (avg) => formatStatsDurationShort(avg.round()),
          current.durationSec,
        ),
      ),
      StatsKpiTile(
        icon: Icons.layers_outlined,
        color: AppColors.statTeal,
        label: 'Serie',
        value: formatStatsDecimal(current.completedSets.toDouble()),
        unit: '',
        delta: previous == null
            ? null
            : StatsDelta.percent(current.completedSets, previous.completedSets),
        caption: '${formatStatsDecimal(current.reps.toDouble())} powt.',
      ),
      StatsKpiTile(
        icon: Icons.emoji_events_outlined,
        color: AppColors.statAmber,
        label: 'Rekordy',
        value: '${s.recordsCount}',
        unit: '',
        delta: s.previousRecordsCount == null
            ? null
            : StatsDelta.absolute(s.recordsCount, s.previousRecordsCount!),
        caption:
            '${current.distinctExercises} ${polishPlural(current.distinctExercises, 'ćwiczenie', 'ćwiczenia', 'ćwiczeń')}',
      ),
      StatsKpiTile(
        icon: Icons.local_fire_department_outlined,
        color: AppColors.statPink,
        label: 'Seria tygodni',
        value: '${s.currentStreakWeeks}',
        unit: polishPlural(
          s.currentStreakWeeks,
          'tydzień',
          'tygodnie',
          'tygodni',
        ),
        caption: 'najdłuższa: ${s.bestStreakWeeks}',
        // Seria nie zależy od zakresu — porównanie nie miałoby sensu.
        showDelta: false,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Trzy kolumny dopiero na szerokich ekranach — na telefonie liczby
        // typu „17 h 40 min” muszą mieć miejsce.
        final columns = constraints.maxWidth >= 560 ? 3 : 2;
        const gap = AppSpacing.xs;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class StatsKpiTile extends StatelessWidget {
  const StatsKpiTile({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.unit,
    this.delta,
    this.caption,
    this.showDelta = true,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String unit;

  /// Zmiana względem poprzedniego okresu; `null` — pokazujemy [caption].
  final StatsDelta? delta;
  final String? caption;
  final bool showDelta;

  @override
  Widget build(BuildContext context) {
    final d = showDelta ? delta : null;
    return Semantics(
      container: true,
      label: [
        label,
        '$value $unit'.trim(),
        if (d != null) 'zmiana ${d.text}' else ?caption,
      ].join(', '),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 15, color: color),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (unit.isNotEmpty)
                      TextSpan(
                        text: ' $unit',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 16,
              child: d != null
                  ? _DeltaLine(delta: d)
                  : Text(
                      caption ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeltaLine extends StatelessWidget {
  const _DeltaLine({required this.delta});

  final StatsDelta delta;

  @override
  Widget build(BuildContext context) {
    final color = switch (delta.direction) {
      > 0 => AppColors.trendUp,
      < 0 => AppColors.trendDown,
      _ => AppColors.textMuted,
    };
    final icon = switch (delta.direction) {
      > 0 => Icons.arrow_upward_rounded,
      < 0 => Icons.arrow_downward_rounded,
      _ => Icons.remove_rounded,
    };
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 2),
        Text(
          delta.text,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        const Flexible(
          child: Text(
            'vs poprz.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
