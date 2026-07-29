import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bottom navigation with a notched, docked center "Trening" button.
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

  static const double barHeight = 64;
  static const double centerDiameter = 56;
  static const double _centerOverlap = centerDiameter / 2;

  final int currentIndex;
  final bool hasActiveSession;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCenterTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        // Extra height on top so the circle stays inside hit-test bounds.
        height: barHeight + _centerOverlap,
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              top: _centerOverlap,
              bottom: 0,
              child: CustomPaint(
                painter: _NotchedBarPainter(notchDepth: 30, notchMargin: 40),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: _centerOverlap,
              bottom: 0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NavItem(
                    index: 0,
                    label: 'Historia',
                    icon: Icons.history_outlined,
                    selectedIcon: Icons.history_rounded,
                    selected: currentIndex == 0,
                    onTap: onDestinationSelected,
                  ),
                  _NavItem(
                    index: 1,
                    label: 'Plany',
                    icon: Icons.format_list_bulleted_rounded,
                    selectedIcon: Icons.format_list_bulleted_rounded,
                    selected: currentIndex == 1,
                    onTap: onDestinationSelected,
                  ),
                  _CenterLabelSlot(
                    label: 'Trening',
                    selected: currentIndex == 2,
                    onTap: onCenterTap,
                  ),
                  _NavItem(
                    index: 3,
                    label: 'Aktywność',
                    icon: Icons.timeline_outlined,
                    selectedIcon: Icons.timeline_rounded,
                    selected: currentIndex == 3,
                    onTap: onDestinationSelected,
                  ),
                  _NavItem(
                    index: 4,
                    label: 'Profil',
                    icon: Icons.person_outline_rounded,
                    selectedIcon: Icons.person_rounded,
                    selected: currentIndex == 4,
                    onTap: onDestinationSelected,
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: _CenterButton(
                  selected: currentIndex == 2,
                  hasActiveSession: hasActiveSession,
                  onTap: onCenterTap,
                ),
              ),
            ),
          ],
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
    return Semantics(
      button: true,
      selected: selected,
      label: 'Trening',
      hint: hasActiveSession ? 'Trwa sesja — wróć do treningu' : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            key: const Key('app-bottom-nav-center'),
            width: AppBottomNav.centerDiameter,
            height: AppBottomNav.centerDiameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              border: selected
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
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
                    top: 1,
                    right: 1,
                    child: Container(
                      key: const Key('app-bottom-nav-active-dot'),
                      width: 12,
                      height: 12,
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
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
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
        child: InkWell(
          onTap: () => onTap(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryVariant.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterLabelSlot extends StatelessWidget {
  const _CenterLabelSlot({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.primaryVariant
                      : AppColors.textSecondary,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotchedBarPainter extends CustomPainter {
  const _NotchedBarPainter({required this.notchDepth, required this.notchMargin});

  final double notchDepth;
  final double notchMargin;

  Path _topEdge(Size size) {
    final centerX = size.width / 2;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(centerX - notchMargin, 0)
      ..cubicTo(
        centerX - notchMargin + 8,
        0,
        centerX - 14,
        notchDepth,
        centerX,
        notchDepth,
      )
      ..cubicTo(
        centerX + 14,
        notchDepth,
        centerX + notchMargin - 8,
        0,
        centerX + notchMargin,
        0,
      )
      ..lineTo(size.width, 0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final edge = _topEdge(size);
    final fill = Path.from(edge)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = AppColors.surface);
    canvas.drawPath(
      edge,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_NotchedBarPainter oldDelegate) =>
      oldDelegate.notchDepth != notchDepth ||
      oldDelegate.notchMargin != notchMargin;
}
