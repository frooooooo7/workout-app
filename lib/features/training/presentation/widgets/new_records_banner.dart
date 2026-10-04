import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/polish_plural.dart';
import '../../domain/models/training_stats.dart';
import 'personal_record_format.dart';

/// „Nowy rekord!” — rekordy pobite w jednym treningu: na podsumowaniu po
/// treningu i w poście w feedzie. Znika, gdy [records] jest puste.
///
/// [maxVisible] skraca listę (karta w feedzie), reszta trafia do linii
/// „i jeszcze N”.
class NewRecordsBanner extends StatelessWidget {
  const NewRecordsBanner({super.key, required this.records, this.maxVisible});

  final List<PersonalRecord> records;
  final int? maxVisible;

  static const _accent = AppColors.statAmber;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox.shrink();
    final limit = maxVisible;
    final visible = limit == null || records.length <= limit
        ? records
        : records.take(limit).toList();
    final hidden = records.length - visible.length;
    final title = records.length == 1
        ? 'Nowy rekord!'
        : '${records.length} ${polishPlural(records.length, 'nowy rekord', 'nowe rekordy', 'nowych rekordów')}!';

    return Container(
      key: const ValueKey('new-records-banner'),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: _accent.withValues(alpha: 0.32)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent.withValues(alpha: 0.16),
            _accent.withValues(alpha: 0.03),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: _accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final record in visible) _RecordLine(record: record),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.only(left: 45, bottom: 6),
              child: Text(
                'i jeszcze $hidden',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordLine extends StatelessWidget {
  const _RecordLine({required this.record});

  final PersonalRecord record;

  @override
  Widget build(BuildContext context) {
    final value = personalRecordValue(record);
    final improvement = personalRecordImprovement(record);
    final kind = personalRecordKindLabel(record.primaryKind);

    return Semantics(
      label: [record.exerciseName, value, kind, ?improvement].join(', '),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 45, top: 4, bottom: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.exerciseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    kind,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (improvement != null)
                  Text(
                    improvement,
                    style: const TextStyle(
                      color: AppColors.trendUp,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
