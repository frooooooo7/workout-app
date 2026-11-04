import 'package:flutter/material.dart';

import '../../../../../../core/theme/app_colors.dart';
import '../../../../../../core/widgets/app_pressable.dart';

/// Oprawa karty pulpitu statystyk: mały szary nagłówek z ikoną tematu,
/// a pod nim to, co karta ma do powiedzenia. Stuknięcie otwiera ekran
/// szczegółów (strzałka po prawej).
class StatsOverviewCard extends StatelessWidget {
  const StatsOverviewCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.onTap,
    this.trailing,
    this.semanticsLabel,
    this.padding = const EdgeInsets.fromLTRB(18, 16, 14, 16),
  });

  /// Wielkimi literami — jedna linia, bez konkurowania z liczbą pod spodem.
  final String title;
  final IconData? icon;
  final Widget child;
  final VoidCallback? onTap;

  /// Zamiast strzałki, np. pigułka „passa 7 tyg.”.
  final Widget? trailing;
  final String? semanticsLabel;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              ?trailing,
              if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      container: true,
      label: semanticsLabel ?? title,
      onTap: onTap,
      child: AppPressable(pressedScale: 0.985, onTap: onTap, child: card),
    );
  }
}
