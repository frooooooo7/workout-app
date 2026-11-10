import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../domain/models/training_stats.dart';
import 'stats_format.dart';

/// Tytuł okresu kalendarzowego ze strzałkami: „Październik 2026”, pod nim
/// „porównanie z wrześniem”. Strzałka w prawo gaśnie na bieżącym okresie,
/// w lewo — gdy dalej nie ma treningów. Dla „Całość” i własnego zakresu
/// strzałek nie ma.
class StatsPeriodNavigator extends StatelessWidget {
  const StatsPeriodNavigator({
    super.key,
    required this.snapshot,
    required this.onShift,
  });

  final TrainingStatsSnapshot snapshot;

  /// -1 wcześniejszy okres, +1 późniejszy.
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final navigable =
        s.range == StatsRange.week ||
        s.range == StatsRange.month ||
        s.range == StatsRange.year;
    final title = formatStatsPeriodTitle(s);
    final subtitle = formatStatsComparisonLabel(s);
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: navigable
                ? _Arrow(
                    key: const ValueKey('stats-period-prev'),
                    icon: Icons.chevron_left_rounded,
                    label: 'Wcześniejszy okres',
                    enabled: s.hasEarlier,
                    onTap: () => onShift(-1),
                  )
                : null,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  key: const ValueKey('stats-period-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            child: navigable
                ? _Arrow(
                    key: const ValueKey('stats-period-next'),
                    icon: Icons.chevron_right_rounded,
                    label: 'Późniejszy okres',
                    enabled: s.offset > 0,
                    onTap: () => onShift(1),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    super.key,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap();
              }
            : null,
        child: Icon(
          icon,
          size: 28,
          color: enabled ? AppColors.textSecondary : AppColors.border,
        ),
      ),
    );
  }
}
