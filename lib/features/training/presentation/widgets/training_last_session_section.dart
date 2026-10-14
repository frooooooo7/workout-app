import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/plan_colors.dart';
import '../../../../core/theme/plan_icons.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../../core/utils/polish_plural.dart';
import '../../../../core/widgets/animated_number.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../domain/models/training_history_models.dart';
import '../../domain/models/training_summary_stats.dart'
    show formatTrainingVolumeKg;
import '../bloc/training_history_cubit.dart';
import 'stats/stats_format.dart';

/// Ostatni trening w jednym wierszu: „Ostatnio: Legs · śr 14 paź · 1 h 12 min
/// · 9 serii”, objętość i liczba rekordów. Stuknięcie otwiera szczegóły
/// sesji (tam też „Powtórz trening”).
class TrainingLastSessionSection extends StatelessWidget {
  const TrainingLastSessionSection({
    super.key,
    required this.state,
    required this.onOpenDetails,
    this.recordsBySession = const {},
  });

  final TrainingHistoryState state;
  final ValueChanged<TrainingSessionListItem> onOpenDetails;

  /// Identyfikator sesji → liczba pobitych w niej rekordów.
  final Map<String, int> recordsBySession;

  @override
  Widget build(BuildContext context) {
    final item = state.items.isEmpty ? null : state.items.first;

    if (item == null) {
      if (state.loading) {
        return const SkeletonPulse(
          label: 'Ładowanie ostatniego treningu',
          child: SkeletonBlock(height: 64, radius: 18),
        );
      }
      return _LastSessionShell(
        leading: Icon(
          state.error != null
              ? Icons.wifi_off_rounded
              : Icons.emoji_events_outlined,
          size: 20,
          color: AppColors.textSecondary,
        ),
        title: state.error != null
            ? 'Nie udało się załadować ostatniego treningu.'
            : 'Ukończ pierwszy trening, a tutaj go zobaczysz.',
      );
    }

    final color = PlanColors.of(item.plan.name, colorKey: item.plan.colorKey);
    final icon = PlanIcons.of(item.plan.name, iconKey: item.plan.iconKey);
    final records = recordsBySession[item.id] ?? 0;
    final volume = item.totalVolumeKg;
    final initial = item.plan.name.trim().isEmpty
        ? '?'
        : item.plan.name.trim().characters.first.toUpperCase();

    return Semantics(
      button: true,
      hint: 'Szczegóły treningu',
      child: AppPressable(
        key: const ValueKey('last-session-details'),
        pressedScale: 0.98,
        onTap: () => onOpenDetails(item),
        child: _LastSessionShell(
          leading: icon != null
              ? Icon(icon, size: 20, color: color)
              : Text(
                  initial,
                  style: TextStyle(
                    color: Color.lerp(color, Colors.white, 0.3),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
          leadingColor: color.withValues(alpha: 0.16),
          title: 'Ostatnio: ${item.plan.name}',
          subtitle: _subtitle(item),
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (volume != null && volume > 0)
                AnimatedNumber(
                  key: const ValueKey('last-session-volume'),
                  value: volume,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutExpo,
                  format: volumeFormatterFor(volume),
                  style: AppTextStyles.number(size: 21),
                ),
              if (records > 0) ...[
                const SizedBox(height: 3),
                Text(
                  '$records ${polishPlural(records, 'rekord', 'rekordy', 'rekordów')}',
                  style: const TextStyle(
                    color: AppColors.record,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
          showChevron: true,
        ),
      ),
    );
  }

  /// „śr 14 paź · 1 h 12 min · 9 serii”.
  static String _subtitle(TrainingSessionListItem item) {
    final date = item.startedAt.toLocal();
    final parts = [
      '${statsWeekdaysShort[date.weekday - 1].toLowerCase()} '
          '${formatStatsDayMonth(date)}',
      if (item.durationSec > 0) formatStatsDurationShort(item.durationSec),
      '${item.completedSetsCount} '
          '${polishPlural(item.completedSetsCount, 'seria', 'serie', 'serii')}',
    ];
    return parts.join(' · ');
  }
}

/// Formater objętości dla licznika: jednostka ustalona z wartości końcowej,
/// żeby w trakcie doliczania nie przeskakiwała z kg na tony.
///
/// Kilogramy: do tony `850 kg`, wyżej tony z dwoma miejscami (`8,29 t`).
/// Funty: jak w statystykach (`18 630 lb`).
String Function(double) volumeFormatterFor(double finalKg) {
  if (WeightUnits.current == WeightUnit.lb) {
    final unit = formatStatsVolume(finalKg).unit;
    return (kg) {
      final lb = WeightUnit.lb.fromKg(kg);
      return unit == 'lb'
          ? '${formatTrainingVolumeKg(lb.round())} lb'
          : '${formatStatsDecimal(lb / 1000)} $unit';
    };
  }
  if (finalKg < 1000) {
    return (kg) => '${formatTrainingVolumeKg(kg.round())} kg';
  }
  return (kg) => '${formatStatsDecimal(kg / 1000, digits: 2)} t';
}

class _LastSessionShell extends StatelessWidget {
  const _LastSessionShell({
    required this.leading,
    required this.title,
    this.leadingColor = AppColors.tile,
    this.subtitle,
    this.trailing,
    this.showChevron = false,
  });

  final Widget leading;
  final Color leadingColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: leadingColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: leading,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: subtitle == null ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: subtitle == null
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    fontSize: subtitle == null ? 13 : 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          if (showChevron) ...[
            const SizedBox(width: 12),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
          ],
        ],
      ),
    );
  }
}
