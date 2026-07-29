import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class TrainingDayHero extends StatelessWidget {
  const TrainingDayHero({
    super.key,
    required this.label,
    required this.isLoading,
    required this.isRestDay,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  static const double diameter = 232;

  final String label;
  final bool isLoading;
  final bool isRestDay;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: !isLoading,
      label: isLoading ? 'Ładowanie' : '$title. $subtitle',
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.18),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: isLoading
                ? const SizedBox(
                    key: ValueKey('hero-loading'),
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 3,
                    ),
                  )
                : Padding(
                    key: ValueKey('hero-content-$isRestDay-$title-$subtitle'),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            if (isRestDay)
                              Image.asset(
                                'assets/images/monk_rest.png',
                                key: const ValueKey('monk-rest-icon'),
                                height: 64,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              )
                            else
                              const Icon(
                                Icons.fitness_center_rounded,
                                key: ValueKey('training-day-icon'),
                                size: 36,
                                color: AppColors.textSecondary,
                              ),
                            const SizedBox(height: 6),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
