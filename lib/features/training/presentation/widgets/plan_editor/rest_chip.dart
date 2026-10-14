import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/app_pressable.dart';
import '../ongoing_workout/rest_timer_controls.dart' show formatRestRemaining;

/// Przerwa ćwiczenia w edycji planu: `⏱ 3:00`. Przerwa domyślna planu jest
/// wyszarzona — od razu widać, które ćwiczenia mają własną.
class RestChip extends StatelessWidget {
  const RestChip({
    super.key,
    required this.seconds,
    required this.isDefault,
    required this.onTap,
  });

  final int seconds;
  final bool isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = formatRestRemaining(Duration(seconds: seconds));
    final foreground = isDefault
        ? AppColors.textMuted
        : const Color(0xFFC9D8FF);
    return Semantics(
      button: true,
      label: isDefault
          ? 'Przerwa domyślna planu $label. Zmień'
          : 'Przerwa po serii $label. Zmień',
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDefault
                ? Colors.transparent
                : AppColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDefault
                  ? AppColors.borderStrong
                  : AppColors.primaryVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_rounded, size: 15, color: foreground),
              const SizedBox(width: 5),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.35),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  label,
                  key: ValueKey(label),
                  style: AppTextStyles.number(size: 18, color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
