import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';

/// Zakładki statystyk. Zakres dat stoi nad nimi i obowiązuje we wszystkich.
enum StatsTab {
  overview,
  progress,
  body,
  consistency;

  String get label => switch (this) {
    StatsTab.overview => 'Przegląd',
    StatsTab.progress => 'Postępy',
    StatsTab.body => 'Ciało',
    StatsTab.consistency => 'Regularność',
  };

  IconData get icon => switch (this) {
    StatsTab.overview => Icons.space_dashboard_rounded,
    StatsTab.progress => Icons.trending_up_rounded,
    StatsTab.body => Icons.accessibility_new_rounded,
    StatsTab.consistency => Icons.event_repeat_rounded,
  };
}

/// Rząd pigułek z ikonami: jedna zakładka statystyk na pigułkę, równej
/// szerokości, żeby cztery zmieściły się bez przewijania.
class StatsTabBar extends StatelessWidget {
  const StatsTabBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final StatsTab selected;
  final ValueChanged<StatsTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tab in StatsTab.values) ...[
          if (tab != StatsTab.values.first)
            const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: _TabPill(
              key: ValueKey('stats-tab-${tab.name}'),
              tab: tab,
              selected: tab == selected,
              onTap: () {
                if (tab == selected) return;
                HapticFeedback.selectionClick();
                onChanged(tab);
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    super.key,
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final StatsTab tab;
  final bool selected;
  final VoidCallback onTap;

  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Statystyki: ${tab.label}',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: _duration,
          curve: Curves.easeOutCubic,
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.16)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected
                  ? AppColors.primaryVariant.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<Color?>(
                duration: _duration,
                curve: Curves.easeOutCubic,
                tween: ColorTween(
                  end: selected
                      ? AppColors.primaryVariant
                      : AppColors.textSecondary,
                ),
                builder: (context, c, _) => Icon(tab.icon, size: 20, color: c),
              ),
              const SizedBox(height: 3),
              // Przy dużej czcionce systemowej „Regularność” nie mieści się
              // w czwartej części paska — skalujemy ją w dół zamiast ucinać.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: _duration,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                  child: Text(tab.label, maxLines: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
