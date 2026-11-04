import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../../core/widgets/app_pressable.dart';
import '../../../domain/models/training_stats.dart';
import '../session_details/session_section_card.dart';
import 'overview/stats_headlines.dart';
import 'overview/stats_strength_summary_card.dart';
import 'stats_navigation.dart';

/// Wszystkie ćwiczenia z okresu od największego wzrostu: mini-wykres
/// szacowanego 1RM i zmiana. Wiersz otwiera szczegóły ćwiczenia.
class StatsAllExercisesCard extends StatefulWidget {
  const StatsAllExercisesCard({super.key, required this.exercises});

  /// Od najczęstszego (tak zwraca kalkulator).
  final List<ExerciseProgress> exercises;

  @override
  State<StatsAllExercisesCard> createState() => _StatsAllExercisesCardState();
}

class _StatsAllExercisesCardState extends State<StatsAllExercisesCard> {
  static const _collapsedRows = 6;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final trends = [for (final e in widget.exercises) StatsExerciseTrend.of(e)]
      ..sort((a, b) {
        // Bez porównania (za mało punktów) na końcu, reszta od wzrostu.
        final ca = a.change;
        final cb = b.change;
        if (ca == null && cb == null) return 0;
        if (ca == null) return 1;
        if (cb == null) return -1;
        return cb.compareTo(ca);
      });
    final visible = _expanded ? trends : trends.take(_collapsedRows).toList();
    return SessionSectionCard(
      title: 'Wszystkie ćwiczenia',
      trailing: const Text(
        'od największego wzrostu',
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: trends.isEmpty
          ? const Text(
              'Brak ćwiczeń w tym okresie.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                  _Row(trend: visible[i]),
                ],
                if (trends.length > _collapsedRows)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryVariant,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                      ),
                      label: Text(_expanded ? 'Zwiń' : 'Pokaż wszystkie'),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.trend});

  final StatsExerciseTrend trend;

  @override
  Widget build(BuildContext context) {
    final e = trend.exercise;
    final canOpen = canOpenStatsExercise(e.exerciseId);
    final details =
        '${e.sessions} ${polishPlural(e.sessions, 'trening', 'treningi', 'treningów')}';
    final row = StatsTrendRow(trend: trend, subtitle: details);
    return Semantics(
      button: canOpen,
      container: true,
      excludeSemantics: true,
      onTap: canOpen ? () => openStatsExercise(context, e.exerciseId) : null,
      label: [
        e.exerciseName,
        details,
        if (trend.currentLabel.isNotEmpty) trend.currentLabel,
      ].join(', '),
      child: canOpen
          ? AppPressable(
              pressedScale: 0.98,
              onTap: () => openStatsExercise(context, e.exerciseId),
              child: row,
            )
          : row,
    );
  }
}
