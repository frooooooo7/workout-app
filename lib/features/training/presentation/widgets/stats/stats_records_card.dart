import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../domain/models/training_stats.dart';
import '../personal_record_format.dart';
import '../session_details/session_section_card.dart';
import 'stats_format.dart';
import 'stats_personal_bests_screen.dart';
import 'stats_navigation.dart';

/// Najnowsze rekordy pobite w zakresie + wejście do listy najlepszych wyników
/// wszystkich ćwiczeń.
class StatsRecordsCard extends StatelessWidget {
  const StatsRecordsCard({
    super.key,
    required this.records,
    required this.bests,
    required this.now,
  });

  /// Rekordy z okna zakresu, najnowsze najpierw.
  final List<PersonalRecord> records;
  final List<ExerciseBest> bests;
  final DateTime now;

  static const _maxRows = 4;

  @override
  Widget build(BuildContext context) {
    final visible = records.take(_maxRows).toList(growable: false);
    return SessionSectionCard(
      icon: Icons.emoji_events_outlined,
      title: 'Rekordy',
      trailing: bests.isEmpty
          ? null
          : TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PersonalBestsScreen(bests: bests),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryVariant,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Wszystkie'),
            ),
      child: visible.isEmpty
          ? _Empty(tracked: bests.length)
          : Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                  _RecordRow(record: visible[i], now: now),
                ],
                if (records.length > visible.length)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '+${records.length - visible.length} '
                        '${polishPlural(records.length - visible.length, 'rekord', 'rekordy', 'rekordów')} '
                        'więcej w tym okresie',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record, required this.now});

  final PersonalRecord record;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final kind = r.primaryKind;
    final value = personalRecordValue(r);
    final improvement = personalRecordImprovement(r);
    final date = formatStatsRelativeDay(r.date.toLocal(), now);
    final canOpen = canOpenStatsExercise(r.exerciseId);

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.statAmber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md - 2),
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              size: 18,
              color: AppColors.statAmber,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.exerciseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      date,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            flex: 3,
                            child: Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(flex: 2, child: _KindBadge(kind: kind)),
                        ],
                      ),
                    ),
                    if (improvement != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        improvement,
                        style: const TextStyle(
                          color: AppColors.trendUp,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (canOpen) ...[
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ],
      ),
    );

    return Semantics(
      button: canOpen,
      label: [
        r.exerciseName,
        value,
        personalRecordKindLabel(kind),
        ?improvement,
        date,
      ].join(', '),
      excludeSemantics: true,
      onTap: canOpen ? () => openStatsExercise(context, r.exerciseId) : null,
      child: canOpen
          ? InkWell(
              onTap: () => openStatsExercise(context, r.exerciseId),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: row,
            )
          : row,
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final PersonalRecordKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      ),
      child: Text(
        personalRecordKindLabel(kind),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.tracked});

  final int tracked;

  @override
  Widget build(BuildContext context) {
    final hint = tracked == 0
        ? 'Rekord pojawi się, gdy powtórzysz ćwiczenie i poprawisz wynik.'
        : 'Śledzimy wyniki w $tracked '
              '${tracked == 1 ? 'ćwiczeniu' : 'ćwiczeniach'} — pobij któryś, '
              'a pojawi się tutaj.';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.md - 2),
          ),
          child: const Icon(
            Icons.emoji_events_outlined,
            size: 18,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Brak nowych rekordów w tym okresie',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                hint,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
