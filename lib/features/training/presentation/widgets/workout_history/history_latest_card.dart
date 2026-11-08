import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../../core/widgets/app_pressable.dart';
import '../../../domain/services/history_feed_builder.dart';
import '../../../domain/services/history_latest.dart';
import '../../../domain/services/workout_comparison.dart';
import '../session_details/session_details_formatters.dart';
import '../workout_summary/workout_comparison_card.dart' show exerciseDeltaText;
import 'history_formatters.dart';
import 'history_line_value.dart';
import 'history_plan_style.dart';
import 'history_record_badge.dart';

/// `DZIŚ`, `WCZORAJ`, `3 DNI TEMU`, a od tygodnia data (`ŚR 28 PAŹ`).
String historyLatestWhen(DateTime day, DateTime today) {
  // Dni liczymy na datach w UTC: różnica dwóch lokalnych północy przez zmianę
  // czasu ma 23 albo 25 godzin i `inDays` zgubiłby dzień.
  final days = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(day.year, day.month, day.day)).inDays;
  if (days <= 0) return 'DZIŚ';
  if (days == 1) return 'WCZORAJ';
  if (days < 7) return '$days DNI TEMU';
  return formatSessionDay(day).toUpperCase();
}

/// Karta „Ostatni trening” na górze Historii: plan, kiedy i ile trwał, trzy
/// kafelki (tonaż, serie, czas) ze zmianą względem poprzedniego treningu tego
/// planu i najlepsze serie głównych ćwiczeń z różnicą. Stuknięcie otwiera
/// szczegóły sesji.
class HistoryLatestCard extends StatelessWidget {
  const HistoryLatestCard({
    super.key,
    required this.latest,
    required this.today,
    this.highlighted = false,
  });

  final HistoryLatest latest;
  final DateTime today;

  /// Krótkie podświetlenie po „Pokaż na liście” z kalendarza.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final entry = latest.entry;
    final session = entry.item;
    final plan = HistoryPlanStyle.of(session);
    final comparison = latest.comparison;
    final totals = comparison?.totals;
    final volume = session.totalVolumeKg ?? 0;
    final sets = session.completedSetsCount;

    final tiles = <Widget>[
      if (volume > 0)
        _Tile(
          key: const ValueKey('latest-volume'),
          value: _splitUnit(formatVolumeKg(volume)),
          label: 'Tonaż',
          delta: totals == null ? null : _volumeDelta(totals),
        )
      else
        _Tile(
          key: const ValueKey('latest-exercises'),
          value: (session.exercisesCount.toString(), null),
          label: polishPlural(
            session.exercisesCount,
            'Ćwiczenie',
            'Ćwiczenia',
            'Ćwiczeń',
          ),
        ),
      _Tile(
        key: const ValueKey('latest-sets'),
        value: (sets.toString(), null),
        label: polishPlural(sets, 'Seria', 'Serie', 'Serii'),
        delta: totals == null ? null : _setsDelta(totals),
      ),
      _Tile(
        key: const ValueKey('latest-time'),
        value: _durationValue(session.durationSec),
        label: 'Czas',
        delta: totals == null ? null : _timeDelta(totals),
      ),
    ];

    final footnote = _footnote(comparison, plan.name);

    return AppPressable(
      onTap: () => context.push('/app/training/history/${session.id}'),
      pressedScale: 0.98,
      child: AnimatedContainer(
        key: const ValueKey('history-latest-card'),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: highlighted
              ? Color.alphaBlend(
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.surface,
                )
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: highlighted ? AppColors.primaryVariant : AppColors.border,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card - 1),
          child: Stack(
            children: [
              // Poświata w kolorze planu w prawym górnym rogu.
              Positioned(
                top: -70,
                right: -50,
                width: 260,
                height: 260,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          plan.color.withValues(alpha: 0.2),
                          plan.color.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'OSTATNI TRENING · '
                            '${historyLatestWhen(entry.day, today)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: plan.color,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ),
                        if (entry.recordsCount > 0) ...[
                          const SizedBox(width: AppSpacing.xs),
                          HistoryRecordBadge(count: entry.recordsCount),
                        ],
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatSessionDay(session.startedAt)} · '
                      '${formatClock(session.startedAt)} · '
                      '${formatHoursMinutes(session.durationSec)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < tiles.length; i++) ...[
                            if (i > 0) const SizedBox(width: AppSpacing.xs),
                            Expanded(child: tiles[i]),
                          ],
                        ],
                      ),
                    ),
                    if (footnote != null) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          footnote,
                          key: const ValueKey('latest-footnote'),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    if (entry.note != null) ...[
                      const SizedBox(height: 6),
                      _NoteLine(note: entry.note!),
                    ],
                    if (entry.lines.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      for (final line in entry.lines)
                        _LineRow(
                          line: line,
                          comparison: latest.comparisonOf(line),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _footnote(WorkoutComparison? comparison, String planName) {
    if (comparison == null) return null;
    return switch (comparison.kind) {
      WorkoutComparisonKind.plan =>
        'Zmiany względem poprzedniego $planName'
            '${comparison.previousDate == null ? '' : ' (${formatSessionDay(comparison.previousDate!)})'}',
      WorkoutComparisonKind.firstOfPlan => 'Pierwszy trening tego planu',
      WorkoutComparisonKind.lastPerformances =>
        'Zmiany względem ostatnich wykonań ćwiczeń',
    };
  }

  /// `9,8 t` → (`9,8`, `t`).
  static (String, String?) _splitUnit(String text) {
    final i = text.lastIndexOf(' ');
    if (i <= 0) return (text, null);
    return (text.substring(0, i), text.substring(i + 1));
  }

  /// `1:04 h` od godziny, niżej `52 min`.
  static (String, String?) _durationValue(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 60) return ('$minutes', 'min');
    return (
      '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}',
      'h',
    );
  }

  static _TileDelta _volumeDelta(ComparisonTotals t) {
    if (t.previousVolumeKg <= 0 || t.volumeKg <= 0) {
      return const _TileDelta.none();
    }
    final percent =
        ((t.volumeKg - t.previousVolumeKg) / t.previousVolumeKg * 100).round();
    if (percent == 0) return const _TileDelta.same();
    return _TileDelta(
      text: '${percent.abs()}%',
      direction: percent > 0 ? 1 : -1,
    );
  }

  static _TileDelta _setsDelta(ComparisonTotals t) {
    final diff = t.setsDelta;
    if (diff == 0) return const _TileDelta.same();
    return _TileDelta(text: '${diff.abs()}', direction: diff > 0 ? 1 : -1);
  }

  /// Czas zawsze szary: krócej nie znaczy lepiej. Poniżej minuty to „bez zmian”.
  static _TileDelta _timeDelta(ComparisonTotals t) {
    final diff = t.durationDeltaSeconds;
    final minutes = (diff.abs() / 60).round();
    if (minutes == 0) return const _TileDelta.same();
    final text = minutes < 60
        ? '$minutes min'
        : '${minutes ~/ 60} h${minutes % 60 == 0 ? '' : ' ${minutes % 60} min'}';
    return _TileDelta(text: text, direction: diff > 0 ? 1 : -1, neutral: true);
  }
}

/// Notatka z treningu w jednej linijce.
class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          const Icon(
            Icons.sticky_note_2_outlined,
            size: 15,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              note.replaceAll(RegExp(r'\s+'), ' '),
              key: const ValueKey('latest-note'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Zmiana pod liczbą w kafelku: `▲ 4%`, `▼ 8 min` albo `= bez zmian`.
class _TileDelta {
  const _TileDelta({
    required this.text,
    required this.direction,
    this.neutral = false,
  });

  const _TileDelta.same() : text = 'bez zmian', direction = 0, neutral = false;

  const _TileDelta.none() : text = '', direction = 0, neutral = false;

  final String text;

  /// 1 w górę, -1 w dół, 0 bez strzałki.
  final int direction;

  /// Szara zamiast zielonej / czerwonej.
  final bool neutral;

  bool get isEmpty => text.isEmpty;
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.value,
    required this.label,
    this.delta,
  });

  final (String, String?) value;
  final String label;
  final _TileDelta? delta;

  @override
  Widget build(BuildContext context) {
    final delta = this.delta;
    final color = delta == null || delta.neutral || delta.direction == 0
        ? AppColors.textMuted
        : delta.direction > 0
        ? AppColors.trendUp
        : AppColors.trendDown;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value.$1, style: AppTextStyles.number(size: 30)),
                if (value.$2 != null) ...[
                  const SizedBox(width: 3),
                  Text(
                    value.$2!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (delta != null && !delta.isEmpty) ...[
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (delta.direction != 0) ...[
                    Icon(
                      delta.direction > 0
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      size: 20,
                      color: color,
                    ),
                  ] else
                    Text(
                      '= ',
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Text(
                    delta.text,
                    maxLines: 1,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: delta.direction == 0
                          ? FontWeight.w500
                          : FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Wiersz ćwiczenia: nazwa, najlepsza seria i zmiana względem ostatniego razu.
class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, this.comparison});

  final HistoryFeedLine line;
  final ExerciseComparison? comparison;

  @override
  Widget build(BuildContext context) {
    final (text, color) = _delta();
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              line.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          HistoryLineValue(line: line, size: 20),
          if (text != null)
            Container(
              width: 64,
              alignment: Alignment.centerRight,
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  (String?, Color) _delta() {
    final c = comparison;
    if (c == null) return (null, AppColors.textMuted);
    return switch (c.trend) {
      ExerciseTrend.improved => ('+${exerciseDeltaText(c)}', AppColors.trendUp),
      ExerciseTrend.worse => ('−${exerciseDeltaText(c)}', AppColors.trendDown),
      ExerciseTrend.same => ('=', AppColors.textMuted),
      ExerciseTrend.fresh => ('nowe', AppColors.primaryVariant),
      ExerciseTrend.skipped => (null, AppColors.textMuted),
    };
  }
}
