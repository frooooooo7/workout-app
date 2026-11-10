import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/utils/polish_plural.dart';
import '../../../../domain/models/training_stats.dart';
import '../stats_format.dart';
import '../stats_detail_screen.dart' show StatsDetail;
import 'stats_headlines.dart';
import 'stats_overview_card.dart';

/// Poniżej tylu treningów w okresie kafle pokazują „za mało danych” zamiast
/// przypadkowych liczb.
const statsTileMinWorkouts = 3;

/// Kafel działu na pulpicie: nagłówek, jedna duża liczba i jedno zdanie.
class StatsTile extends StatelessWidget {
  const StatsTile({
    super.key,
    required this.title,
    required this.onTap,
    this.value,
    this.unit,
    this.caption,
    this.accent,
    this.footer,
  });

  final String title;
  final VoidCallback onTap;

  /// Duża liczba; `null` = brak danych (pokazujemy kreskę).
  final String? value;
  final String? unit;
  final String? caption;
  final Color? accent;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final noData = value == null;
    return StatsOverviewCard(
      title: title,
      onTap: onTap,
      semanticsLabel:
          '$title, ${noData ? 'za mało danych' : '$value ${unit ?? ''} ${caption ?? ''}'.trim()}',
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (noData)
            const Text(
              'za mało danych',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        color: accent ?? AppColors.textPrimary,
                        fontSize: 34,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    if (unit != null && unit!.isNotEmpty)
                      TextSpan(
                        text: ' $unit',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                maxLines: 1,
              ),
            ),
          if (!noData && caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ],
          if (footer != null) ...[const SizedBox(height: 8), footer!],
        ],
      ),
    );
  }
}

/// Liczby i zdania kafli — osobno od widgetów, żeby dało się je testować.
abstract final class StatsTileData {
  static bool enoughData(TrainingStatsSnapshot s) =>
      s.current.workouts >= statsTileMinWorkouts;

  /// `(rosnące, porównywalne)` wśród głównych ćwiczeń okresu.
  static ({int up, int total}) strength(TrainingStatsSnapshot s) {
    final trends = StatsHeadlines.strengthTrends(s.exercises);
    var up = 0;
    var total = 0;
    for (final t in trends) {
      if (t.direction == null) continue;
      total++;
      if (t.direction == 1) up++;
    }
    return (up: up, total: total);
  }

  /// „Przysiad 120 kg × 5, wczoraj”; `null` bez rekordów w okresie.
  static String? latestRecord(TrainingStatsSnapshot s, DateTime now) {
    if (s.records.isEmpty) return null;
    final r = s.records.first;
    final w = r.weightKg;
    final result = w != null && w > 0
        ? ' ${formatStatsWeight(w)}${r.reps == null ? '' : ' × ${r.reps}'}'
        : '';
    return 'ostatni: ${r.exerciseName}$result, '
        '${formatStatsRelativeDay(r.date.toLocal(), now)}';
  }

  /// Partie w zakresie 10–20 serii tygodniowo i wszystkie trenowane partie.
  static ({int inBand, int total}) muscles(TrainingStatsSnapshot s) {
    var inBand = 0;
    for (final r in s.recovery) {
      final spw = r.setsPerWeek.round();
      if (spw >= 10 && spw <= 20) inBand++;
    }
    return (inBand: inBand, total: s.recovery.length);
  }

  /// Treningi tygodniowo z jedną cyfrą po przecinku.
  static String perWeek(double v) =>
      formatStatsDecimal(double.parse(v.toStringAsFixed(1)));

  static String recordsNoun(int n) => polishPlural(
    n,
    'ćwiczenie z rekordem',
    'ćwiczenia z rekordem',
    'ćwiczeń z rekordem',
  );
}

/// Cztery kafle działów w siatce 2×2.
class StatsTilesGrid extends StatelessWidget {
  const StatsTilesGrid({
    super.key,
    required this.snapshot,
    required this.now,
    required this.onOpen,
  });

  final TrainingStatsSnapshot snapshot;
  final DateTime now;
  final ValueChanged<StatsDetail> onOpen;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final enough = StatsTileData.enoughData(s);
    final strength = StatsTileData.strength(s);
    final muscles = StatsTileData.muscles(s);
    final perWeek = s.habits.workoutsPerWeek;
    final favorite = StatsHeadlines.favorite(s.habits);
    final latest = StatsTileData.latestRecord(s, now);
    final streak = s.streakWeeks;

    final tiles = <Widget>[
      StatsTile(
        key: const ValueKey('stats-tile-strength'),
        title: 'Siła',
        onTap: () => onOpen(StatsDetail.strength),
        value: enough && strength.total > 0 ? '${strength.up}' : null,
        unit: 'z ${strength.total} ćwiczeń',
        caption: 'rośnie w tym okresie',
      ),
      StatsTile(
        key: const ValueKey('stats-tile-records'),
        title: 'Rekordy',
        onTap: () => onOpen(StatsDetail.records),
        value: '${s.recordsCount}',
        accent: s.recordsCount > 0 ? AppColors.statAmber : null,
        caption: s.recordsCount == 0
            ? 'brak rekordów w tym okresie'
            : '${StatsTileData.recordsNoun(s.recordsCount)}'
                  '${latest == null ? '' : '\n$latest'}',
      ),
      StatsTile(
        key: const ValueKey('stats-tile-muscles'),
        title: 'Mięśnie',
        onTap: () => onOpen(StatsDetail.muscles),
        value: enough && muscles.total > 0 ? '${muscles.inBand}' : null,
        unit: 'z ${muscles.total} partii',
        caption: 'w zakresie 10–20 serii/tydz.',
      ),
      StatsTile(
        key: const ValueKey('stats-tile-consistency'),
        title: 'Regularność',
        onTap: () => onOpen(StatsDetail.consistency),
        value: perWeek == null || perWeek <= 0
            ? null
            : StatsTileData.perWeek(perWeek),
        unit: '/ tydz.',
        caption: favorite?.toLowerCase(),
        footer: streak > 0
            ? FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _StreakChip(weeks: streak),
              )
            : null,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.weeks});

  final int weeks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.statAmber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 14,
            color: AppColors.statAmber,
          ),
          const SizedBox(width: 4),
          Text(
            'passa ${StatsHeadlines.streak(weeks)}',
            style: const TextStyle(
              color: AppColors.statAmber,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
