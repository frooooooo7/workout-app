import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Nagłówek podstrony: przycisk „Wstecz”, tytuł wyrównany do lewej i akcje
/// po prawej — ten sam wzór co [AppTabHeader] z przyciskiem powrotu, żeby
/// cała aplikacja miała jeden styl nagłówków.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
    this.height = 52.0,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  final String title;

  /// Opcjonalny callback przycisku powrotu.
  final VoidCallback? onBack;

  /// Opcjonalne akcje po prawej stronie (np. przyciski menu, edycji).
  final List<Widget>? actions;

  /// Wysokość wiersza nagłówka.
  final double height;

  /// Zewnętrzny margines wokół nagłówka.
  final EdgeInsetsGeometry margin;

  @override
  Size get preferredSize => Size.fromHeight(
    height + (margin is EdgeInsets ? (margin as EdgeInsets).vertical : 12.0),
  );

  @override
  Widget build(BuildContext context) {
    final actions = this.actions ?? const <Widget>[];
    return Padding(
      padding: margin,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            if (onBack != null) ...[
              AppHeaderIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Wstecz',
                onTap: onBack!,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.screenTitle.copyWith(fontSize: 20),
                ),
              ),
            ),
            for (final action in actions) ...[
              const SizedBox(width: AppSpacing.xs),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

/// Kafelek-przycisk 44 px dla [AppHeader] z animacją wciśnięcia.
class AppHeaderIconButton extends StatefulWidget {
  const AppHeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.size = AppSpacing.minTapTarget,
    this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final double size;
  final String? tooltip;
  final bool active;

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
    final accent = widget.active ? AppColors.success : AppColors.borderStrong;
    final fill = widget.active
        ? AppColors.success.withValues(alpha: 0.16)
        : AppColors.tile;
    final iconColor =
        widget.iconColor ??
        (widget.active ? AppColors.success : AppColors.iconOnTile);

    final button = GestureDetector(
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
            borderRadius: BorderRadius.circular(AppRadius.tile),
            color: fill,
            border: Border.all(
              color: widget.active ? accent.withValues(alpha: 0.7) : accent,
            ),
          ),
          child: Center(child: Icon(widget.icon, size: 20, color: iconColor)),
        ),
      ),
    );

    final labeled = Semantics(
      button: true,
      label: widget.tooltip,
      child: button,
    );

    if (widget.tooltip == null) return labeled;
    return Tooltip(message: widget.tooltip!, child: labeled);
  }
}
