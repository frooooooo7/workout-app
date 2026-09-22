import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_tab_header.dart';

class TrainingHeader extends StatelessWidget {
  const TrainingHeader({
    super.key,
    this.onAddTap,
    this.addTooltip = 'Dodaj trening',
    this.activePlanName,
    this.onActiveTap,
    this.onLibraryTap,
    this.gutter = AppSpacing.pageGutter,
  });

  final VoidCallback? onAddTap;
  final String addTooltip;
  final String? activePlanName;
  final VoidCallback? onActiveTap;
  final VoidCallback? onLibraryTap;

  /// Poziomy margines — jak treść zakładki.
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final hasActiveSession =
        activePlanName != null && activePlanName!.trim().isNotEmpty;

    return AppTabHeader(
      title: 'Trening',
      gutter: gutter,
      actions: [
        if (hasActiveSession)
          _ActiveSessionButton(
            planName: activePlanName!,
            onTap: onActiveTap ?? () {},
          ),
        if (onLibraryTap != null)
          AppTabHeaderButton(
            tooltip: 'Biblioteka ćwiczeń',
            icon: Icons.menu_book_rounded,
            onPressed: onLibraryTap!,
          ),
        AppTabHeaderButton(
          tooltip: addTooltip,
          icon: Icons.add_rounded,
          accent: true,
          onPressed: onAddTap ?? () {},
        ),
      ],
    );
  }
}

/// Kompaktowa pigułka „Trwa” — nazwa planu w podpowiedzi i dla czytnika
/// ekranu, bo w pasku z trzema kafelkami nie mieści się czytelnie.
class _ActiveSessionButton extends StatelessWidget {
  const _ActiveSessionButton({required this.planName, required this.onTap});

  final String planName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Wróć do treningu: $planName',
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const SizedBox(
            height: AppSpacing.minTapTarget,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_circle_fill_rounded,
                    color: AppColors.primaryVariant,
                    size: 20,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Trwa',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
