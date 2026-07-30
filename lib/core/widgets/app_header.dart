import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Uniwersalny, czysty i minimalistyczny header aplikacji.
///
/// Komponent służy jako spójny nagłówek na różnych ekranach aplikacji.
/// Posiada idealnie wycentrowany tytuł względem pełnej szerokości kontenera
/// (niezależnie od obecności przycisku powrotu czy akcji po prawej stronie).
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
    this.height = 54.0,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  /// Dynamiczny tytuł wyświetlany w ścisłym centrum headera.
  final String title;

  /// Opcjonalny callback przycisku powrotu. Gdy obecny, wyświetla okrągły przycisk ze strzałką.
  final VoidCallback? onBack;

  /// Opcjonalne akcje po prawej stronie (np. przyciski menu, edycji, filtrowania).
  final List<Widget>? actions;

  /// Wysokość wewnętrznego kontenera headera.
  final double height;

  /// Zewnętrzny margines wokół pływającego kontenera headera.
  final EdgeInsetsGeometry margin;

  @override
  Size get preferredSize => Size.fromHeight(
    height + (margin is EdgeInsets ? (margin as EdgeInsets).vertical : 12.0),
  );

  @override
  Widget build(BuildContext context) {
    final hasBack = onBack != null;
    final hasActions = actions != null && actions!.isNotEmpty;

    // Obliczamy bezpieczny margines boczny dla tytułu, aby długi tekst
    // ulegał obcięciu (ellipsis) zanim dotknie przycisków lewych/prawych.
    final double actionsWidth = hasActions
        ? (actions!.length * 44.0 + 8.0)
        : 16.0;
    final double leftWidth = hasBack ? 52.0 : 16.0;
    final double maxSidePadding = actionsWidth > leftWidth
        ? actionsWidth
        : leftWidth;

    return Padding(
      padding: margin,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.7),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 14,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Tytuł — Absolutnie wycentrowany względem całej szerokości kontenera
            Padding(
              padding: EdgeInsets.symmetric(horizontal: maxSidePadding),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),

            // 2. Przyciski po lewej i prawej stronie w osobnej warstwie
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Przycisk powrotu po lewej stronie
                  if (hasBack)
                    AppHeaderIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: onBack!,
                    )
                  else
                    const SizedBox.shrink(),

                  // Przycisk(i) akcji po prawej stronie
                  if (hasActions)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: actions!
                          .map(
                            (action) => Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: action,
                            ),
                          )
                          .toList(),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Standaryzowany, okrągły przycisk akcji dla [AppHeader] z mikroadaptacyjną animacją wciśnięcia.
class AppHeaderIconButton extends StatefulWidget {
  const AppHeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.size = 38.0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final double size;

  @override
  State<AppHeaderIconButton> createState() => _AppHeaderIconButtonState();
}

class _AppHeaderIconButtonState extends State<AppHeaderIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.94,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _controller.forward();
  void _onTapUp(TapUpDetails details) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceVariant.withValues(alpha: 0.6),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.6),
              width: 1.0,
            ),
          ),
          child: Center(
            child: Icon(
              widget.icon,
              size: 19,
              color: widget.iconColor ?? Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
