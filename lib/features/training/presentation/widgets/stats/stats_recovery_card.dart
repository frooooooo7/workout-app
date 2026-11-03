import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/polish_plural.dart';
import '../../../../library/domain/models/exercise.dart';
import '../../../domain/models/training_stats.dart';
import '../session_details/session_section_card.dart';

/// Regeneracja: partie podzielone na „Gotowe do treningu”, „Odpoczywają”
/// i „Dawno bez treningu”. Liczy się wyłącznie liczba dni od ostatniej pracy
/// partii, z całej historii.
class StatsRecoveryCard extends StatelessWidget {
  const StatsRecoveryCard({super.key, required this.recovery});

  /// Od ostatnio trenowanej pozycji.
  final List<MuscleRecoveryStat> recovery;

  @override
  Widget build(BuildContext context) {
    final groups = <_Group, List<MuscleRecoveryStat>>{
      for (final g in _Group.values) g: [],
    };
    for (final stat in recovery) {
      groups[_Group.of(stat.daysSince)]!.add(stat);
    }
    return SessionSectionCard(
      title: 'Regeneracja',
      trailing: const Text(
        'z całej historii',
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      child: recovery.isEmpty
          ? const Text(
              'Brak danych o partiach — przypisz mięśnie do ćwiczeń.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final group in _Group.values)
                  if (groups[group]!.isNotEmpty) ...[
                    if (group != _firstShown(groups))
                      const SizedBox(height: AppSpacing.md),
                    Text(
                      group.label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final stat in groups[group]!)
                          _MuscleChip(stat: stat, group: group),
                      ],
                    ),
                  ],
              ],
            ),
    );
  }

  static _Group? _firstShown(Map<_Group, List<MuscleRecoveryStat>> groups) {
    for (final g in _Group.values) {
      if (groups[g]!.isNotEmpty) return g;
    }
    return null;
  }
}

enum _Group {
  ready('Gotowe do treningu', AppColors.success),
  recovering('Odpoczywają', AppColors.statAmber),
  longAgo('Dawno bez treningu', AppColors.textMuted);

  const _Group(this.label, this.color);

  final String label;
  final Color color;

  static _Group of(int daysSince) {
    if (daysSince <= 1) return _Group.recovering;
    if (daysSince <= 6) return _Group.ready;
    return _Group.longAgo;
  }
}

/// Grupy zbiorcze pełną nazwą („Nogi”, „Plecy”), granularne skróconą.
String _label(MuscleGroup group) =>
    group.isCoarse ? group.label : group.shortLabel;

/// „dziś”, „wczoraj”, „4 dni”, „3 tyg.”, „2 mies.”, „rok”.
String _short(int daysSince) {
  if (daysSince <= 0) return 'dziś';
  if (daysSince == 1) return 'wczoraj';
  if (daysSince < 14) {
    return '$daysSince ${polishPlural(daysSince, 'dzień', 'dni', 'dni')}';
  }
  if (daysSince < 60) return '${daysSince ~/ 7} tyg.';
  if (daysSince < 365) return '${daysSince ~/ 30} mies.';
  return '${daysSince ~/ 365} r.';
}

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({required this.stat, required this.group});

  final MuscleRecoveryStat stat;
  final _Group group;

  @override
  Widget build(BuildContext context) {
    final name = _label(stat.muscle);
    final since = _short(stat.daysSince);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$name, ${group.label.toLowerCase()}, ostatnio $since',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: group.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$name · $since',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
