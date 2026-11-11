import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/polish_plural.dart';

/// Rząd kółek-skrótów pod nagłówkiem profilu: seria tygodni, rekordy, plany
/// i „Postępy” (prywatne, z kłódką).
class ProfileHighlightsRow extends StatelessWidget {
  const ProfileHighlightsRow({
    super.key,
    this.streakWeeks = 0,
    this.onStreakTap,
    this.onRecordsTap,
    this.onPlansTap,
    this.onProgressTap,
  });

  final int streakWeeks;
  final VoidCallback? onStreakTap;
  final VoidCallback? onRecordsTap;
  final VoidCallback? onPlansTap;
  final VoidCallback? onProgressTap;

  @override
  Widget build(BuildContext context) {
    final hasStreak = streakWeeks > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
      child: Row(
        children: [
          Expanded(
            child: ProfileHighlight(
              key: const ValueKey('profile-highlight-streak'),
              icon: Icons.local_fire_department_outlined,
              label: hasStreak
                  ? '$streakWeeks ${polishPlural(streakWeeks, 'tydzień', 'tygodnie', 'tygodni')}'
                  : 'Seria',
              ringColor: hasStreak ? AppColors.planAmber : AppColors.border,
              iconColor: hasStreak
                  ? AppColors.planAmber
                  : AppColors.textSecondary,
              onTap: onStreakTap,
            ),
          ),
          Expanded(
            child: ProfileHighlight(
              key: const ValueKey('profile-highlight-records'),
              icon: Icons.emoji_events_outlined,
              label: 'Rekordy',
              ringColor: AppColors.planAmber,
              iconColor: AppColors.planAmber,
              onTap: onRecordsTap,
            ),
          ),
          Expanded(
            child: ProfileHighlight(
              key: const ValueKey('profile-highlight-plans'),
              icon: Icons.format_list_bulleted_rounded,
              label: 'Plany',
              ringColor: AppColors.primary,
              iconColor: AppColors.primaryVariant,
              onTap: onPlansTap,
            ),
          ),
          Expanded(
            child: ProfileHighlight(
              key: const ValueKey('profile-highlight-progress'),
              icon: Icons.lock_outline_rounded,
              label: 'Postępy',
              ringColor: AppColors.border,
              iconColor: AppColors.textSecondary,
              onTap: onProgressTap,
              semanticsHint: 'Widzisz to tylko Ty',
            ),
          ),
        ],
      ),
    );
  }
}

/// Jedno kółko z podpisem. Cel dotyku obejmuje kółko i podpis.
class ProfileHighlight extends StatelessWidget {
  const ProfileHighlight({
    super.key,
    required this.icon,
    required this.label,
    required this.ringColor,
    required this.iconColor,
    this.onTap,
    this.semanticsHint,
  });

  final IconData icon;
  final String label;
  final Color ringColor;
  final Color iconColor;
  final VoidCallback? onTap;
  final String? semanticsHint;

  static const _diameter = 60.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: label,
      hint: semanticsHint,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _diameter,
                height: _diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: ringColor, width: 2),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(height: AppSpacing.xs),
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
            ],
          ),
        ),
      ),
    );
  }
}
