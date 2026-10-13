import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pływający pasek nawigacji z wyróżnionym środkowym przyciskiem „Trening”.
///
/// Order: Historia (0), Plany (1), [Trening (2)], Aktywność (3), Profil (4).
/// Purely presentational — the parent resolves taps.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.hasActiveSession,
    required this.onDestinationSelected,
    required this.onCenterTap,
  });

  static const double barHeight = 68;
  static const double centerSize = 52;

  /// Odstęp paska od krawędzi ekranu (boki / dół nad bezpiecznym obszarem).
  static const double sideInset = 12;
  static const double bottomInset = 14;

  final int currentIndex;
  final bool hasActiveSession;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCenterTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: bottomInset),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: sideInset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: barHeight,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: const Color(0xDB141924),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    _NavItem(
                      index: 0,
                      label: 'Historia',
                      icon: Icons.history_rounded,
                      selected: currentIndex == 0,
                      onTap: onDestinationSelected,
                    ),
                    _NavItem(
                      index: 1,
                      label: 'Plany',
                      icon: Icons.format_list_bulleted_rounded,
                      selected: currentIndex == 1,
                      onTap: onDestinationSelected,
                    ),
                    Expanded(
                      child: Center(
                        child: _CenterButton(
                          selected: currentIndex == 2,
                          hasActiveSession: hasActiveSession,
                          onTap: onCenterTap,
                        ),
                      ),
                    ),
                    _NavItem(
                      index: 3,
                      label: 'Aktywność',
                      icon: Icons.monitor_heart_outlined,
                      selected: currentIndex == 3,
                      onTap: onDestinationSelected,
                    ),
                    _NavItem(
                      index: 4,
                      label: 'Profil',
                      icon: Icons.person_outline_rounded,
                      selected: currentIndex == 4,
                      onTap: onDestinationSelected,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterButton extends StatelessWidget {
  const _CenterButton({
    required this.selected,
    required this.hasActiveSession,
    required this.onTap,
  });

  final bool selected;
  final bool hasActiveSession;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Trening',
      hint: hasActiveSession ? 'Trwa sesja — wróć do treningu' : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: AnimatedContainer(
            key: const Key('app-bottom-nav-center'),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: AppBottomNav.centerSize,
            height: AppBottomNav.centerSize,
            decoration: BoxDecoration(
              borderRadius: radius,
              color: AppColors.primary,
              border: selected
                  ? Border.all(color: Colors.white.withValues(alpha: 0.35))
                  : null,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(
                    alpha: selected ? 0.55 : 0.35,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Center(
                  child: Icon(
                    Icons.fitness_center_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                if (hasActiveSession)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      key: const Key('app-bottom-nav-active-dot'),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                        border: Border.all(
                          color: AppColors.background,
                          width: 2.5,
                        ),
                      ),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryVariant : AppColors.textSecondary;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onTap(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                child: Text(label, maxLines: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
