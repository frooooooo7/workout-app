import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/units/weight_unit.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../../core/widgets/app_pressable.dart';
import '../../../../library/domain/models/exercise_tracking.dart';
import '../../../domain/services/history_feed_builder.dart';
import '../session_details/session_details_formatters.dart';
import 'history_formatters.dart';
import 'history_plan_style.dart';
import 'history_record_badge.dart';

/// Dzień z treningami: po lewej numer dnia i skrót dnia tygodnia z pionową
/// linią, po prawej karty treningów z tego dnia (zwykle jedna).
class HistoryDayBlock extends StatelessWidget {
  const HistoryDayBlock({
    super.key,
    required this.day,
    required this.entries,
    this.highlighted = false,
  });

  final DateTime day;

  /// Treningi z tego dnia, od najnowszego.
  final List<HistoryFeedEntry> entries;

  /// Krótkie podświetlenie po „Pokaż na liście” z kalendarza.
  final bool highlighted;

  static const dateColumnWidth = 40.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DateColumn(day: day),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.xs),
                    HistorySessionCard(
                      entry: entries[i],
                      highlighted: highlighted,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateColumn extends StatelessWidget {
  const _DateColumn({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: formatSessionDay(day),
      excludeSemantics: true,
      child: SizedBox(
        width: HistoryDayBlock.dateColumnWidth,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Text(formatDayNumber(day), style: AppTextStyles.number(size: 25)),
            const SizedBox(height: 2),
            Text(
              formatWeekdayShort(day).toUpperCase(),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Karta treningu: plan, godzina i czas, główne ćwiczenia z najlepszą serią
/// (rekord na złoto), notatka, a na dole tonaż, serie i liczba ćwiczeń.
/// Stuknięcie otwiera szczegóły sesji.
class HistorySessionCard extends StatelessWidget {
  const HistorySessionCard({
    super.key,
    required this.entry,
    this.highlighted = false,
  });

  final HistoryFeedEntry entry;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final session = entry.item;
    final plan = HistoryPlanStyle.of(session);
    final volume = session.totalVolumeKg ?? 0;
    final sets = session.completedSetsCount;
    final exercises = session.exercisesCount;

    return AppPressable(
      onTap: () => context.push('/app/training/history/${session.id}'),
      pressedScale: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: highlighted
              ? Color.alphaBlend(
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.surface,
                )
              : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: highlighted ? AppColors.primaryVariant : AppColors.border,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 14,
              bottom: 14,
              width: 3.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: plan.color,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(3),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          plan.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '${formatClock(session.startedAt)} · '
                        '${formatHoursMinutes(session.durationSec)}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  if (entry.lines.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    for (final line in entry.lines) _ExerciseLine(line: line),
                  ],
                  if (entry.note != null) ...[
                    const SizedBox(height: 4),
                    _NoteLine(note: entry.note!),
                  ],
                  if (entry.lines.isNotEmpty || entry.note != null) ...[
                    const SizedBox(height: 8),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                    const SizedBox(height: 8),
                  ] else
                    const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                if (volume > 0) ...[
                                  Text(
                                    formatVolumeKg(volume),
                                    style: AppTextStyles.number(size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                _Stat(
                                  value: sets,
                                  label: polishPlural(
                                    sets,
                                    'seria',
                                    'serie',
                                    'serii',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _Stat(
                                  value: exercises,
                                  label: polishPlural(
                                    exercises,
                                    'ćwiczenie',
                                    'ćwiczenia',
                                    'ćwiczeń',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (entry.recordsCount > 0) ...[
                        const SizedBox(width: AppSpacing.xs),
                        HistoryRecordBadge(count: entry.recordsCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `16 serii` — liczba cyframi liczbowymi, podpis drobnym drukiem.
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('$value', style: AppTextStyles.number(size: 22)),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12.5)),
      ],
    );
  }
}

class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
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

class _ExerciseLine extends StatelessWidget {
  const _ExerciseLine({required this.line});

  final HistoryFeedLine line;

  @override
  Widget build(BuildContext context) {
    final color = line.isRecord ? AppColors.record : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              line.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSubtle,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (line.isRecord) ...[
            const Icon(
              Icons.emoji_events_rounded,
              size: 14,
              color: AppColors.record,
            ),
            const SizedBox(width: 3),
          ],
          _LineValue(line: line, color: color),
        ],
      ),
    );
  }
}

/// Najlepsza seria ćwiczenia: `92,5 kg × 5`, `12 powt.`, `3,2 km · 18:10`.
class _LineValue extends StatelessWidget {
  const _LineValue({required this.line, required this.color});

  final HistoryFeedLine line;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final number = AppTextStyles.number(size: 20, color: color, height: 1.1);
    final unit = TextStyle(
      color: line.isRecord
          ? AppColors.record.withValues(alpha: 0.75)
          : AppColors.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );

    final spans = <InlineSpan>[];
    final weight = line.weightKg;
    final reps = line.reps;
    if (line.durationSeconds != null || line.distanceM != null) {
      final distance = line.distanceM;
      final duration = line.durationSeconds;
      spans.add(
        TextSpan(
          text: [
            if (distance != null) line.distanceUnit.formatWithUnit(distance),
            if (duration != null) formatSetDuration(duration),
          ].join(' · '),
          style: number.copyWith(fontSize: 18),
        ),
      );
    } else if (weight != null) {
      spans
        ..add(TextSpan(text: formatWeightNumber(weight), style: number))
        ..add(TextSpan(text: ' ${WeightUnits.current.label}', style: unit));
      if (reps != null) {
        spans
          ..add(TextSpan(text: ' × ', style: unit))
          ..add(TextSpan(text: '$reps', style: number));
      }
    } else if (reps != null) {
      spans
        ..add(TextSpan(text: '$reps', style: number))
        ..add(TextSpan(text: ' powt.', style: unit));
    } else {
      return const SizedBox.shrink();
    }
    return Text.rich(TextSpan(children: spans), maxLines: 1);
  }
}
