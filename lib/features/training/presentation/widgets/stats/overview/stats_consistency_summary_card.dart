import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../domain/models/training_stats.dart';
import 'stats_headlines.dart';
import 'stats_overview_card.dart';

/// Pulpit: ile treningów w tygodniu średnio, kiedy zwykle trenujesz, passa
/// i dwanaście ostatnich tygodni.
class StatsConsistencySummaryCard extends StatelessWidget {
  const StatsConsistencySummaryCard({
    super.key,
    required this.snapshot,
    required this.onTap,
  });

  final TrainingStatsSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final headline = StatsHeadlines.perWeek(s.habits.workoutsPerWeek);
    final favorite = StatsHeadlines.favorite(s.habits);
    final streak = s.streakWeeks;
    final weeks = _weeks(s);

    return StatsOverviewCard(
      title: 'Regularność',
      icon: Icons.event_available_rounded,
      onTap: onTap,
      semanticsLabel: 'Regularność, ${headline ?? 'szczegóły'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline ?? 'Za mało treningów na średnią',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 19,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (favorite != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        favorite,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (streak > 0) ...[
                const SizedBox(width: 10),
                _StreakPill(weeks: streak),
              ],
            ],
          ),
          if (weeks.isNotEmpty) ...[
            const SizedBox(height: 14),
            _WeekCells(weeks: weeks, goal: s.goal?.goal),
          ],
        ],
      ),
    );
  }

  /// Treningi w kolejnych tygodniach (najstarszy pierwszy, bieżący ostatni):
  /// z celem tygodnie celu, bez niego tygodnie heatmapy aktywności.
  static List<int> _weeks(TrainingStatsSnapshot s) {
    final goal = s.goal;
    if (goal != null && goal.weeks.isNotEmpty) {
      return [for (final w in goal.weeks) w.workouts];
    }
    final a = s.activity;
    return [
      for (var w = 0; w < a.weeks; w++)
        [
          for (var d = 0; d < 7; d++)
            a
                    .dayAt(
                      DateTime(
                        a.start.year,
                        a.start.month,
                        a.start.day + w * 7 + d,
                      ),
                    )
                    ?.workouts ??
                0,
        ].fold<int>(0, (x, y) => x + y),
    ];
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.weeks});

  final int weeks;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Passa: ${StatsHeadlines.streak(weeks)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.statOrange.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              size: 16,
              color: AppColors.statOrange,
            ),
            const SizedBox(width: 4),
            Text(
              StatsHeadlines.streak(weeks),
              style: const TextStyle(
                color: AppColors.statOrange,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekCells extends StatelessWidget {
  const _WeekCells({required this.weeks, required this.goal});

  final List<int> weeks;
  final int? goal;

  static const _height = 30.0;

  @override
  Widget build(BuildContext context) {
    final last = weeks.length - 1;
    return SizedBox(
      height: _height + 6,
      child: Row(
        children: [
          for (var i = 0; i < weeks.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _Cell(count: weeks[i], goal: goal, current: i == last),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.count, required this.goal, required this.current});

  final int count;
  final int? goal;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final g = goal;
    final met = g != null && count >= g;
    final Color fill;
    if (g != null) {
      fill = met ? AppColors.success : AppColors.surfaceVariant;
    } else {
      fill = count == 0
          ? AppColors.surfaceVariant
          : AppColors.primaryVariant.withValues(
              alpha: (0.35 + 0.15 * count).clamp(0.35, 1.0),
            );
    }
    // Niewykonany cel: dolna część komórki pokazuje, ile z niego zrobiono.
    final partial = g != null && !met && count > 0 ? count / g : 0.0;
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(7),
        border: current
            ? Border.all(color: AppColors.primaryVariant, width: 1.5)
            : null,
      ),
      child: partial > 0
          ? Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: partial.clamp(0.15, 1.0),
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
