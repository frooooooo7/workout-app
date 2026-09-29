import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_pressable.dart';
import '../../../domain/models/training_stats.dart';
import '../session_details/session_section_card.dart';
import 'stats_navigation.dart';

/// Krótkie wnioski z danych („Objętość wzrosła o 12%”). Wniosek o konkretnym
/// ćwiczeniu otwiera jego szczegóły.
class StatsInsightsCard extends StatelessWidget {
  const StatsInsightsCard({super.key, required this.insights});

  /// Od najpilniejszego (tak zwraca kalkulator).
  final List<StatsInsight> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) return const SizedBox.shrink();

    return SessionSectionCard(
      icon: Icons.lightbulb_outline_rounded,
      title: 'Wnioski',
      child: Column(
        children: [
          for (var i = 0; i < insights.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            _InsightRow(insight: insights[i]),
          ],
        ],
      ),
    );
  }
}

IconData _iconOf(StatsInsightKind kind) => switch (kind) {
  StatsInsightKind.inactivity => Icons.hourglass_bottom_rounded,
  StatsInsightKind.goalMet => Icons.flag_rounded,
  StatsInsightKind.goalBehind => Icons.flag_outlined,
  StatsInsightKind.volumeUp => Icons.trending_up_rounded,
  StatsInsightKind.volumeDown => Icons.trending_down_rounded,
  StatsInsightKind.records => Icons.emoji_events_outlined,
  StatsInsightKind.plateau => Icons.horizontal_rule_rounded,
  StatsInsightKind.progress => Icons.show_chart_rounded,
  StatsInsightKind.neglected => Icons.warning_amber_rounded,
  StatsInsightKind.streak => Icons.local_fire_department_outlined,
};

Color _colorOf(StatsInsightTone tone) => switch (tone) {
  StatsInsightTone.positive => AppColors.trendUp,
  StatsInsightTone.attention => AppColors.statAmber,
  StatsInsightTone.neutral => AppColors.primaryVariant,
};

class _InsightRow extends StatelessWidget {
  const _InsightRow({required this.insight});

  final StatsInsight insight;

  @override
  Widget build(BuildContext context) {
    final i = insight;
    final exerciseId = i.exerciseId;
    final canOpen = exerciseId != null && canOpenStatsExercise(exerciseId);
    final color = _colorOf(i.tone);

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md - 2),
            ),
            child: Icon(_iconOf(i.kind), size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              i.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
          if (canOpen) ...[
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

    return Semantics(
      button: canOpen,
      container: true,
      excludeSemantics: true,
      label: i.text,
      // excludeSemantics zdejmuje akcje dzieci — dotknięcie musi być tu.
      onTap: canOpen ? () => openStatsExercise(context, exerciseId) : null,
      child: canOpen
          ? AppPressable(
              pressedScale: 0.98,
              onTap: () => openStatsExercise(context, exerciseId),
              child: row,
            )
          : row,
    );
  }
}
