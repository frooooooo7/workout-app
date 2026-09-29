import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../domain/models/training_stats.dart';
import '../session_details/session_section_card.dart';
import 'stats_format.dart';

/// Kiedy i jak trenujesz: rozkład na dni tygodnia, pory dnia i średnie
/// jednej sesji.
class StatsHabitsCard extends StatelessWidget {
  const StatsHabitsCard({super.key, required this.habits});

  final TrainingHabits habits;

  @override
  Widget build(BuildContext context) {
    return SessionSectionCard(
      icon: Icons.schedule_rounded,
      title: 'Nawyki treningowe',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(
            title: 'Dni tygodnia',
            detail: habits.favoriteWeekday == null
                ? null
                : 'najczęściej: ${statsWeekdaysLong[habits.favoriteWeekday! - 1]}',
          ),
          const SizedBox(height: AppSpacing.sm),
          _WeekdayBars(
            counts: habits.weekdayCounts,
            favorite: habits.favoriteWeekday,
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel(
            title: 'Pora dnia',
            detail: habits.favoriteTimeOfDay == null
                ? null
                : 'najczęściej: ${habits.favoriteTimeOfDay!.label.toLowerCase()}',
          ),
          const SizedBox(height: AppSpacing.sm),
          _TimeOfDaySection(
            counts: habits.timeOfDayCounts,
            favorite: habits.favoriteTimeOfDay,
          ),
          const SizedBox(height: AppSpacing.lg),
          _HabitMetrics(habits: habits),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        if (detail != null)
          Expanded(
            child: Text(
              detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _WeekdayBars extends StatelessWidget {
  const _WeekdayBars({required this.counts, required this.favorite});

  final List<int> counts;

  /// [DateTime.weekday] ulubionego dnia.
  final int? favorite;

  static const _barArea = 64.0;

  @override
  Widget build(BuildContext context) {
    final max = counts.fold<int>(0, (m, v) => v > m ? v : m);
    return Semantics(
      container: true,
      label: [
        for (var i = 0; i < 7; i++)
          '${statsWeekdaysLong[i]}: ${i < counts.length ? counts[i] : 0}',
      ].join(', '),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: _WeekdayBar(
                label: statsWeekdaysShort[i],
                count: i < counts.length ? counts[i] : 0,
                max: max,
                height: _barArea,
                isFavorite: favorite == i + 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekdayBar extends StatelessWidget {
  const _WeekdayBar({
    required this.label,
    required this.count,
    required this.max,
    required this.height,
    required this.isFavorite,
  });

  final String label;
  final int count;
  final int max;
  final double height;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    // Pusty dzień dostaje niski tor, żeby rząd słupków nie miał dziur.
    final barHeight = max == 0 || count == 0
        ? 4.0
        : (height * count / max).clamp(6.0, height);
    final color = count == 0
        ? AppColors.chartTrack
        : isFavorite
        ? AppColors.primaryVariant
        : AppColors.primary.withValues(alpha: 0.4);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count == 0 ? '' : '$count',
          style: TextStyle(
            color: isFavorite ? AppColors.textPrimary : AppColors.textMuted,
            fontSize: 11,
            fontWeight: isFavorite ? FontWeight.w700 : FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: height,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              widthFactor: 0.62,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                height: barHeight,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isFavorite ? AppColors.textPrimary : AppColors.textMuted,
            fontSize: 11,
            fontWeight: isFavorite ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

Color _timeOfDayColor(TrainingTimeOfDay time) => switch (time) {
  TrainingTimeOfDay.morning => AppColors.statAmber,
  TrainingTimeOfDay.midday => AppColors.statTeal,
  TrainingTimeOfDay.evening => AppColors.statIndigo,
  TrainingTimeOfDay.night => AppColors.statPink,
};

class _TimeOfDaySection extends StatelessWidget {
  const _TimeOfDaySection({required this.counts, required this.favorite});

  final Map<TrainingTimeOfDay, int> counts;
  final TrainingTimeOfDay? favorite;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (sum, v) => sum + v);
    int percentOf(TrainingTimeOfDay t) =>
        total == 0 ? 0 : ((counts[t] ?? 0) * 100 / total).round();

    return Column(
      children: [
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 10,
              child: total == 0
                  ? const ColoredBox(color: AppColors.chartTrack)
                  : Row(
                      children: [
                        for (final t in TrainingTimeOfDay.values)
                          if ((counts[t] ?? 0) > 0)
                            Expanded(
                              flex: counts[t]!,
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                color: favorite == null || t == favorite
                                    ? _timeOfDayColor(t)
                                    : _timeOfDayColor(
                                        t,
                                      ).withValues(alpha: 0.55),
                              ),
                            ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final t in TrainingTimeOfDay.values)
          _TimeOfDayRow(
            time: t,
            count: counts[t] ?? 0,
            percent: percentOf(t),
            isFavorite: t == favorite,
          ),
      ],
    );
  }
}

class _TimeOfDayRow extends StatelessWidget {
  const _TimeOfDayRow({
    required this.time,
    required this.count,
    required this.percent,
    required this.isFavorite,
  });

  final TrainingTimeOfDay time;
  final int count;
  final int percent;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '${time.label}, godziny ${time.hours}: $percent%',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: count == 0
                    ? AppColors.chartTrack
                    : _timeOfDayColor(time),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              time.label,
              style: TextStyle(
                color: isFavorite
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: isFavorite ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                time.hours,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: TextStyle(
                color: isFavorite
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitMetrics extends StatelessWidget {
  const _HabitMetrics({required this.habits});

  final TrainingHabits habits;

  static String? _decimal(double? v) =>
      v == null ? null : formatStatsDecimal(v);

  @override
  Widget build(BuildContext context) {
    final duration = habits.avgDurationSec == null
        ? null
        : formatStatsDuration(habits.avgDurationSec!);
    final items = [
      (label: 'Śr. czas sesji', value: duration?.value, unit: duration?.unit),
      (
        label: 'Serie / trening',
        value: _decimal(habits.avgSetsPerWorkout),
        unit: null,
      ),
      (
        label: 'Powt. / serię',
        value: _decimal(habits.avgRepsPerSet),
        unit: null,
      ),
      (label: 'Śr. RIR', value: _decimal(habits.avgRir), unit: null),
      (
        label: 'Treningi / tydz.',
        value: _decimal(habits.workoutsPerWeek),
        unit: null,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 420 ? 3 : 2;
        const gap = AppSpacing.xs;
        final lastRowStart = items.length - items.length % columns;
        double widthAt(int index) {
          // Niepełny ostatni rząd rozciągamy na całą szerokość — bez dziury.
          final inRow = index >= lastRowStart && items.length % columns != 0
              ? items.length % columns
              : columns;
          return (constraints.maxWidth - gap * (inRow - 1)) / inRow;
        }

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                width: widthAt(i),
                child: _MetricTile(
                  label: items[i].label,
                  value: items[i].value,
                  unit: items[i].unit,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, this.value, this.unit});

  final String label;

  /// `null` — brak danych, pokazujemy „—”.
  final String? value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final shown = value ?? '—';
    return Semantics(
      container: true,
      label:
          '$label: ${value == null ? 'brak danych' : '$shown ${unit ?? ''}'.trim()}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: shown,
                      style: TextStyle(
                        color: value == null
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (value != null && unit != null && unit!.isNotEmpty)
                      TextSpan(
                        text: ' $unit',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
