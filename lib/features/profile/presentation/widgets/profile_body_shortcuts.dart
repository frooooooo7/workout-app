import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../training/presentation/widgets/stats/stats_format.dart';
import '../bloc/profile_body_cubit.dart';

/// Dwa kafelki pod kartą tygodnia: „Masa ciała” (ostatnia waga i zmiana)
/// i „Pomiary ciała” (data ostatniego wpisu). Dzięki nim dane o ciele nie
/// siedzą już tylko w Ustawieniach.
class ProfileBodyShortcuts extends StatelessWidget {
  const ProfileBodyShortcuts({
    super.key,
    required this.summary,
    required this.today,
    this.onWeightTap,
    this.onMeasurementsTap,
  });

  final ProfileBodySummary summary;
  final DateTime today;
  final VoidCallback? onWeightTap;
  final VoidCallback? onMeasurementsTap;

  @override
  Widget build(BuildContext context) {
    final weight = summary.weightKg;
    final delta = summary.weightDeltaKg;
    final last = summary.lastMeasurementOn;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _ShortcutTile(
                key: const ValueKey('profile-shortcut-weight'),
                icon: Icons.monitor_weight_outlined,
                title: 'Masa ciała',
                value: weight == null ? 'Dodaj' : formatWeightWithUnit(weight),
                valueIsPlaceholder: weight == null,
                caption: weight == null
                    ? 'pierwszy pomiar'
                    : _deltaCaption(delta, summary.weightOn),
                onTap: onWeightTap,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _ShortcutTile(
                key: const ValueKey('profile-shortcut-measurements'),
                icon: Icons.straighten_rounded,
                title: 'Pomiary',
                value: last == null ? 'Dodaj' : _lastLabel(last),
                valueIsPlaceholder: last == null,
                caption: last == null ? 'obwody i tkanka' : 'ostatni wpis',
                onTap: onMeasurementsTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _deltaCaption(double? delta, DateTime? on) {
    if (delta == null) {
      // Brak zmiany do pokazania (stary albo jedyny pomiar) — podajemy datę,
      // żeby nikt nie wziął starej wagi za bieżącą.
      return on == null
          ? 'ostatni pomiar'
          : 'pomiar: ${_lastLabel(on).toLowerCase()}';
    }
    final value = formatWeightNumber(delta.abs());
    if (value == '0') return 'bez zmian w 30 dni';
    final arrow = delta < 0 ? '↓' : '↑';
    return '$arrow $value ${WeightUnits.current.label} w 30 dni';
  }

  String _lastLabel(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'Dziś';
    if (day == DateTime(today.year, today.month, today.day - 1)) {
      return 'Wczoraj';
    }
    final base = formatStatsDayMonth(date);
    return date.year == today.year ? base : '$base ${date.year}';
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.caption,
    required this.valueIsPlaceholder,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String caption;
  final bool valueIsPlaceholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title: $value, $caption',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md - 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: AppColors.primaryVariant),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      color: valueIsPlaceholder
                          ? AppColors.primaryVariant
                          : AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
