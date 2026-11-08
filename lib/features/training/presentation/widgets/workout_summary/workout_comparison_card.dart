import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/units/weight_unit.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../domain/models/training_session.dart';
import '../../../domain/services/cardio_insights.dart';
import '../../../domain/services/live_workout_insights.dart'
    show formatSetResult;
import '../../../domain/services/workout_comparison.dart';
import '../session_details/session_details_formatters.dart';

/// „Porównanie z poprzednim” — karta pod liczbami treningu: werdykt z paskiem,
/// trzy sumy z różnicą i lista ćwiczeń „było → dziś”, które rozwijają się
/// seria po serii. Przy pierwszym treningu planu zamiast karty jedna linijka.
class WorkoutComparisonCard extends StatefulWidget {
  const WorkoutComparisonCard({
    super.key,
    required this.comparison,
    this.onOpenPrevious,
  });

  final WorkoutComparison comparison;

  /// Otwiera poprzedni trening planu (data w nagłówku karty).
  final void Function(String sessionId)? onOpenPrevious;

  @override
  State<WorkoutComparisonCard> createState() => _WorkoutComparisonCardState();
}

class _WorkoutComparisonCardState extends State<WorkoutComparisonCard> {
  final Set<String> _expanded = {};

  void _toggle(String key) {
    setState(() {
      if (!_expanded.remove(key)) _expanded.add(key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final comparison = widget.comparison;
    if (comparison.kind == WorkoutComparisonKind.firstOfPlan) {
      return _FirstOfPlanLine(planName: comparison.planName);
    }

    final verdict = comparison.verdict;
    final totals = comparison.totals;
    final previousId = comparison.previousSessionId;
    final previousDate = comparison.previousDate;

    return Container(
      key: const ValueKey('workout-comparison-card'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            date: previousDate,
            onTap: previousId == null || widget.onOpenPrevious == null
                ? null
                : () => widget.onOpenPrevious!(previousId),
          ),
          if (verdict != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _VerdictBlock(verdict: verdict, exercises: comparison.exercises),
          ],
          if (totals != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _Divider(),
            const SizedBox(height: AppSpacing.sm),
            _TotalsRow(totals: totals),
          ],
          const SizedBox(height: AppSpacing.xs),
          for (final exercise in comparison.exercises) ...[
            _Divider(),
            _ExerciseRow(
              exercise: exercise,
              expanded: _expanded.contains(exercise.key),
              // Trening bez planu: zawsze. W planie tylko wtedy, gdy „było”
              // pochodzi z innego treningu niż data w nagłówku karty.
              showDate:
                  comparison.kind == WorkoutComparisonKind.lastPerformances ||
                  (exercise.previousDate != null &&
                      exercise.previousDate != comparison.previousDate),
              onToggle: _canExpand(exercise)
                  ? () => _toggle(exercise.key)
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  bool _canExpand(ExerciseComparison e) =>
      e.trend != ExerciseTrend.fresh &&
      e.trend != ExerciseTrend.skipped &&
      e.sets.isNotEmpty;
}

Color _trendColor(ExerciseTrend trend) => switch (trend) {
  ExerciseTrend.improved => AppColors.trendUp,
  ExerciseTrend.worse => AppColors.trendDown,
  ExerciseTrend.fresh => AppColors.primaryVariant,
  ExerciseTrend.same || ExerciseTrend.skipped => AppColors.textSubtle,
};

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, color: AppColors.border.withValues(alpha: 0.6));
}

class _FirstOfPlanLine extends StatelessWidget {
  const _FirstOfPlanLine({required this.planName});

  final String planName;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('workout-comparison-first'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.compare_arrows_rounded,
              color: AppColors.primaryVariant,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pierwszy trening „$planName”',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Następnym razem porównamy go z dzisiejszym.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.date, required this.onTap});

  final DateTime? date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    final dateText = hasDate ? _shortDate(date!) : null;
    return Row(
      children: [
        const Icon(
          Icons.compare_arrows_rounded,
          size: 19,
          color: AppColors.primaryVariant,
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Porównanie z poprzednim',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
        ),
        if (dateText != null)
          InkWell(
            key: const ValueKey('workout-comparison-previous-link'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dateText,
                    style: const TextStyle(
                      color: AppColors.primaryVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.primaryVariant,
                    ),
                ],
              ),
            ),
          )
        else
          const Text(
            'ostatnie wykonania',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

/// `pon, 2 lis`.
String _shortDate(DateTime date) =>
    '${formatWeekdayShort(date)}, ${formatDayNumber(date)} '
    '${formatMonthShort(date)}';

class _VerdictBlock extends StatelessWidget {
  const _VerdictBlock({required this.verdict, required this.exercises});

  final ComparisonVerdict verdict;
  final List<ExerciseComparison> exercises;

  @override
  Widget build(BuildContext context) {
    final compared = verdict.compared;
    final (title, icon, color) = switch (verdict.kind) {
      ComparisonVerdictKind.progress => (
        'Progres w ${verdict.improved} z $compared '
            '${polishPlural(compared, 'ćwiczenia', 'ćwiczeń', 'ćwiczeń')}',
        Icons.trending_up_rounded,
        AppColors.trendUp,
      ),
      ComparisonVerdictKind.same => (
        'Tak samo jak ostatnio',
        Icons.trending_flat_rounded,
        AppColors.textSubtle,
      ),
      ComparisonVerdictKind.worse => (
        'Słabiej w ${verdict.worse} z $compared '
            '${polishPlural(compared, 'ćwiczenia', 'ćwiczeń', 'ćwiczeń')}',
        Icons.trending_flat_rounded,
        AppColors.textSubtle,
      ),
    };
    final subtitle = _verdictSubtitle(verdict);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: [title, ?subtitle].join('. '),
          excludeSemantics: true,
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      key: const ValueKey('workout-comparison-verdict'),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _SegmentBar(exercises: exercises),
      ],
    );
  }

  /// Reszta wyników, których nie ma w tytule: „1 bez zmian · 1 słabiej · 1 nowe”.
  String? _verdictSubtitle(ComparisonVerdict v) {
    final parts = <String>[
      if (v.kind == ComparisonVerdictKind.worse && v.improved > 0)
        '${v.improved} ${polishPlural(v.improved, 'progres', 'progresy', 'progresów')}',
      if (v.kind != ComparisonVerdictKind.same && v.same > 0)
        '${v.same} bez zmian',
      if (v.kind == ComparisonVerdictKind.progress && v.worse > 0)
        '${v.worse} słabiej',
      if (v.fresh > 0) '${v.fresh} nowe',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// Jeden odcinek na każde porównane ćwiczenie: zielone, szare, czerwone.
class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.exercises});

  final List<ExerciseComparison> exercises;

  @override
  Widget build(BuildContext context) {
    final order = [
      ExerciseTrend.improved,
      ExerciseTrend.same,
      ExerciseTrend.worse,
    ];
    final segments = [
      for (final trend in order)
        for (final e in exercises)
          if (e.trend == trend) trend,
    ];
    return Row(
      key: const ValueKey('workout-comparison-bar'),
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: segments[i] == ExerciseTrend.same
                    ? AppColors.surfaceVariant
                    : _trendColor(segments[i]),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.totals});

  final ComparisonTotals totals;

  @override
  Widget build(BuildContext context) {
    final volume = _volumeDelta(totals);
    final sets = _setsDelta(totals);
    final time = _timeDelta(totals);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _TotalCell(
              key: const ValueKey('comparison-volume'),
              label: 'Objętość',
              delta: volume,
            ),
          ),
          const _CellDivider(),
          Expanded(
            child: _TotalCell(
              key: const ValueKey('comparison-sets'),
              label: 'Serie',
              delta: sets,
            ),
          ),
          const _CellDivider(),
          Expanded(
            child: _TotalCell(
              key: const ValueKey('comparison-time'),
              label: 'Czas',
              delta: time,
            ),
          ),
        ],
      ),
    );
  }

  _TotalDelta _volumeDelta(ComparisonTotals t) {
    if (t.volumeKg <= 0 && t.previousVolumeKg <= 0) {
      return const _TotalDelta(text: '—');
    }
    final diff = t.volumeDeltaKg;
    final was = t.previousVolumeKg <= 0
        ? 'było 0 ${WeightUnits.current.label}'
        : 'było ${formatVolumeKg(t.previousVolumeKg)}';
    if (diff.abs() < 0.5) return _TotalDelta(text: 'tyle samo', was: was);
    return _TotalDelta(
      text: formatVolumeKg(diff.abs()),
      was: was,
      direction: diff > 0 ? 1 : -1,
    );
  }

  _TotalDelta _setsDelta(ComparisonTotals t) {
    final diff = t.setsDelta;
    final was = 'było ${t.previousSets}';
    if (diff == 0) return _TotalDelta(text: 'tyle samo', was: was);
    return _TotalDelta(
      text: '${diff.abs()}',
      was: was,
      direction: diff > 0 ? 1 : -1,
    );
  }

  /// Czas zawsze szary: krócej nie znaczy lepiej. Poniżej minuty to „tyle samo”.
  _TotalDelta _timeDelta(ComparisonTotals t) {
    final diff = t.durationDeltaSeconds;
    final was = 'było ${formatDigitalDuration(t.previousDurationSeconds)}';
    final minutes = (diff.abs() / 60).round();
    if (diff.abs() < 60 || minutes == 0) {
      return _TotalDelta(text: 'tyle samo', was: was);
    }
    return _TotalDelta(
      text: '${diff > 0 ? '+' : '−'}${_minutesText(minutes)}',
      was: was,
      neutral: true,
    );
  }

  String _minutesText(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }
}

class _TotalDelta {
  const _TotalDelta({
    required this.text,
    this.was,
    this.direction = 0,
    this.neutral = false,
  });

  final String text;
  final String? was;

  /// 1 w górę (zielony), -1 w dół (czerwony), 0 bez strzałki.
  final int direction;
  final bool neutral;
}

class _CellDivider extends StatelessWidget {
  const _CellDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    color: AppColors.border.withValues(alpha: 0.6),
  );
}

class _TotalCell extends StatelessWidget {
  const _TotalCell({super.key, required this.label, required this.delta});

  final String label;
  final _TotalDelta delta;

  @override
  Widget build(BuildContext context) {
    final color = delta.neutral || delta.direction == 0
        ? AppColors.textPrimary
        : delta.direction > 0
        ? AppColors.trendUp
        : AppColors.trendDown;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (delta.direction != 0) ...[
                  Icon(
                    delta.direction > 0
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 2),
                ],
                Text(
                  delta.text,
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (delta.was != null) ...[
            const SizedBox(height: 2),
            Text(
              delta.was!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Ćwiczenia ──────────────────────────────────────────────────────────

/// Wynik serii do pokazania: `82,5 × 8`, `× 14`, kardio `3,2 km · 18:10`.
String _formatResult(
  SetResult? result,
  ExerciseComparison exercise, {
  WeightUnit? unit,
}) {
  if (result == null || result.isEmpty) return '—';
  if (exercise.isCardio) {
    return formatCardioTotals(
          CardioTotals(
            seconds: result.seconds ?? 0,
            meters: result.meters ?? 0,
          ),
          exercise.tracking,
          exercise.distanceUnit,
        ) ??
        '—';
  }
  return formatSetResult(result.weightKg, result.reps, unit: unit) ?? '—';
}

/// Chip z różnicą: `2,5 kg`, `1 powt.`, `0,4 km`, `0:30`. Bez znaku — kierunek
/// pokazuje kolor albo strzałka.
String exerciseDeltaText(ExerciseComparison exercise) {
  final delta = exercise.delta;
  if (delta == null) return 'bez zmian';
  final value = delta.value.abs();
  return switch (delta.kind) {
    DeltaKind.weight => formatWeightWithUnit(value),
    DeltaKind.reps => '${value.round()} powt.',
    DeltaKind.distance => exercise.distanceUnit.formatWithUnit(value.round()),
    DeltaKind.duration => formatSetDuration(value.round()),
  };
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.expanded,
    required this.showDate,
    required this.onToggle,
  });

  final ExerciseComparison exercise;
  final bool expanded;

  /// Trening bez planu: przy ćwiczeniu data jego ostatniego wykonania.
  final bool showDate;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final trend = exercise.trend;
    final color = _trendColor(trend);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: ValueKey('comparison-exercise-${exercise.key}'),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.exerciseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      _Subtitle(exercise: exercise, showDate: showDate),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (trend != ExerciseTrend.skipped)
                  _Chip(
                    text: trend == ExerciseTrend.fresh
                        ? 'Nowe'
                        : exerciseDeltaText(exercise),
                    color: color,
                    icon: trend == ExerciseTrend.improved
                        ? Icons.arrow_upward_rounded
                        : trend == ExerciseTrend.worse
                        ? Icons.arrow_downward_rounded
                        : null,
                  ),
                SizedBox(
                  width: 28,
                  child: onToggle == null
                      ? null
                      : Icon(
                          expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: AppColors.textSecondary,
                        ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? _SetsTable(exercise: exercise)
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.exercise, required this.showDate});

  final ExerciseComparison exercise;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(
      color: AppColors.textMuted,
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    const strong = TextStyle(
      color: AppColors.textSubtle,
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    switch (exercise.trend) {
      case ExerciseTrend.skipped:
        final n = exercise.workingSets;
        return Text(
          exercise.completedSets > 0
              ? 'bez wpisanego wyniku'
              : '0/$n ${polishPlural(n, 'seria', 'serie', 'serii')}',
          style: muted,
        );
      case ExerciseTrend.fresh:
        return Text.rich(
          TextSpan(
            style: muted,
            children: [
              const TextSpan(text: 'pierwszy raz · '),
              TextSpan(
                text: _formatResult(exercise.today, exercise),
                style: strong,
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case ExerciseTrend.improved:
      case ExerciseTrend.same:
      case ExerciseTrend.worse:
        final date = showDate && exercise.previousDate != null
            ? ' · ${formatDayNumber(exercise.previousDate!)} '
                  '${formatMonthShort(exercise.previousDate!)}'
            : '';
        return Text.rich(
          TextSpan(
            style: muted,
            children: [
              TextSpan(text: _formatResult(exercise.previous, exercise)),
              const TextSpan(text: '  →  '),
              TextSpan(
                text: _formatResult(exercise.today, exercise),
                style: strong.copyWith(color: AppColors.textPrimary),
              ),
              if (date.isNotEmpty) TextSpan(text: date),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rozwinięcie ćwiczenia: serie robocze obok siebie.
class _SetsTable extends StatelessWidget {
  const _SetsTable({required this.exercise});

  final ExerciseComparison exercise;

  @override
  Widget build(BuildContext context) {
    final date = exercise.previousDate;
    final header = date == null ? 'POPRZEDNIO' : _shortDate(date).toUpperCase();
    const headerStyle = TextStyle(
      color: AppColors.textLabel,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    );
    final volumeLine = _volumeLine();
    return Container(
      key: ValueKey('comparison-sets-${exercise.key}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 44,
                child: Text('SERIA', style: headerStyle),
              ),
              Expanded(child: Text(header, style: headerStyle)),
              const Expanded(child: Text('DZIŚ', style: headerStyle)),
              const SizedBox(width: 22),
            ],
          ),
          const SizedBox(height: 6),
          for (final row in exercise.sets)
            _SetRow(exercise: exercise, row: row),
          if (volumeLine != null) ...[const SizedBox(height: 4), volumeLine],
        ],
      ),
    );
  }

  Widget? _volumeLine() {
    if (exercise.isCardio) return null;
    final before = exercise.previousVolumeKg;
    final now = exercise.todayVolumeKg;
    if (before <= 0 || now <= 0) return null;
    final percent = ((now - before) / before * 100).round();
    final color = percent > 0
        ? AppColors.trendUp
        : percent < 0
        ? AppColors.trendDown
        : AppColors.textSubtle;
    return Row(
      children: [
        const Text(
          'Objętość ćwiczenia',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${formatVolumeKg(before)} → ${formatVolumeKg(now)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text(
          percent == 0 ? '0%' : '${percent > 0 ? '+' : '−'}${percent.abs()}%',
          style: TextStyle(
            color: color,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.exercise, required this.row});

  final ExerciseComparison exercise;
  final SetComparison row;

  @override
  Widget build(BuildContext context) {
    final direction = row.direction;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${row.index}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              _formatResult(row.previous, exercise),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              _formatResult(row.today, exercise),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 22,
            child: direction == null || direction == 0
                ? null
                : Icon(
                    direction > 0
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 18,
                    color: direction > 0
                        ? AppColors.trendUp
                        : AppColors.trendDown,
                  ),
          ),
        ],
      ),
    );
  }
}
