import 'dart:ui';

import 'package:flutter/foundation.dart';
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
    this.activityBadge,
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

  /// Nieprzeczytane powiadomienia — kropka z liczbą na „Aktywności”.
  final ValueListenable<int>? activityBadge;

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
                      badge: activityBadge,
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
    this.badge,
  });

  final int index;
  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<int> onTap;
  final ValueListenable<int>? badge;

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
                child: badge == null
                    ? Icon(icon, color: color, size: 22)
                    : Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(icon, color: color, size: 22),
                          Positioned(
                            top: -5,
                            right: -9,
                            child: _NavBadge(count: badge!),
                          ),
                        ],
                      ),
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

/// Liczba na ikonie paska. Przebudowuje tylko siebie, nie cały pasek.
class _NavBadge extends StatelessWidget {
  const _NavBadge({required this.count});

  final ValueListenable<int> count;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: count,
      builder: (context, value, _) => AnimatedScale(
        key: const Key('app-bottom-nav-activity-badge'),
        scale: value > 0 ? 1 : 0,
        duration: const Duration(milliseconds: 240),
        curve: value > 0 ? Curves.elasticOut : Curves.easeIn,
        child: Container(
          constraints: const BoxConstraints(minWidth: 17),
          height: 17,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFF141924), width: 2),
          ),
          child: Text(
            value > 9 ? '9+' : '${value > 0 ? value : ''}',
            style: const TextStyle(
              color: AppColors.onPrimary,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
