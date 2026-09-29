import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../../core/widgets/app_pressable.dart';
import '../../../domain/models/training_stats.dart';
import '../session_details/session_section_card.dart';
import 'stats_format.dart';
import 'stats_navigation.dart';

/// Rekordy całych treningów z historii: najcięższy, najdłuższy, z największą
/// liczbą serii i najlepszy tydzień. Rekord sesji otwiera jej szczegóły.
class StatsSessionRecordsCard extends StatelessWidget {
  const StatsSessionRecordsCard({super.key, required this.records});

  final SessionRecords records;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      for (final kind in SessionRecordKind.values)
        if (records.of(kind) case final record?)
          _SessionRecordRow(record: record),
      if (records.bestWeek case final week?) _BestWeekRow(week: week),
    ];

    return SessionSectionCard(
      icon: Icons.workspace_premium_outlined,
      title: 'Rekordy sesji',
      child: records.isEmpty
          ? const Text(
              'Ukończ trening z ciężarami, aby zobaczyć rekordy sesji.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                  rows[i],
                ],
              ],
            ),
    );
  }
}

class _SessionRecordRow extends StatelessWidget {
  const _SessionRecordRow({required this.record});

  final SessionRecord record;

  static String _label(SessionRecordKind kind) => switch (kind) {
    SessionRecordKind.volume => 'Najcięższy trening',
    SessionRecordKind.duration => 'Najdłuższy trening',
    SessionRecordKind.sets => 'Najwięcej serii',
  };

  static IconData _icon(SessionRecordKind kind) => switch (kind) {
    SessionRecordKind.volume => Icons.fitness_center_rounded,
    SessionRecordKind.duration => Icons.timer_outlined,
    SessionRecordKind.sets => Icons.layers_outlined,
  };

  static StatsValue _value(SessionRecord r) => switch (r.kind) {
    SessionRecordKind.volume => formatStatsVolume(r.value),
    SessionRecordKind.duration => formatStatsDuration(r.value.round()),
    SessionRecordKind.sets => (
      value: '${r.value.round()}',
      unit: polishPlural(r.value.round(), 'seria', 'serie', 'serii'),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final r = record;
    final name = r.name.trim();
    final date = formatStatsLongDate(r.date.toLocal());
    final value = _value(r);
    final label = _label(r.kind);

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: [
        label,
        '${value.value} ${value.unit}',
        if (name.isNotEmpty) name,
        date,
      ].join(', '),
      // excludeSemantics zdejmuje akcje dzieci — dotknięcie musi być tu.
      onTap: () => openStatsSession(context, r.sessionId),
      child: AppPressable(
        pressedScale: 0.98,
        onTap: () => openStatsSession(context, r.sessionId),
        child: _RecordTile(
          icon: _icon(r.kind),
          label: label,
          value: value,
          // Data idzie pierwsza — to nazwa planu skraca się z wielokropkiem.
          detail: name.isEmpty ? date : '$date · $name',
          tappable: true,
        ),
      ),
    );
  }
}

class _BestWeekRow extends StatelessWidget {
  const _BestWeekRow({required this.week});

  final BestWeek week;

  @override
  Widget build(BuildContext context) {
    final value = formatStatsVolume(week.volumeKg);
    final workouts =
        '${week.workouts} '
        '${polishPlural(week.workouts, 'trening', 'treningi', 'treningów')}';
    final since = 'tydz. od ${formatStatsDayMonth(week.start)}';

    return Semantics(
      container: true,
      excludeSemantics: true,
      label:
          'Najlepszy tydzień, ${value.value} ${value.unit}, $workouts, '
          '$since',
      child: _RecordTile(
        icon: Icons.emoji_events_rounded,
        label: 'Najlepszy tydzień',
        value: value,
        detail: '$workouts · $since',
        tappable: false,
      ),
    );
  }
}

/// Wspólny wygląd wiersza: ikona, podpis, wartość i linijka szczegółów.
class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.tappable,
  });

  final IconData icon;
  final String label;
  final StatsValue value;

  /// Linijka pod wartością: data i plan albo opis tygodnia.
  final String detail;
  final bool tappable;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            child: Icon(icon, size: 18, color: AppColors.statAmber),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: value.value,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: ' ${value.unit}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (tappable) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ],
      ),
    );
  }
}
