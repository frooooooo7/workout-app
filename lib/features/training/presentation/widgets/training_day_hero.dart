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
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                        const SizedBox(height: 12),
                        if (isRestDay)
                          Image.asset(
                            'assets/images/monk_rest.png',
                            key: const ValueKey('monk-rest-icon'),
                            height: 78,
                            fit: BoxFit.contain,
                          )
                        else
                          Icon(
                            Icons.fitness_center_rounded,
                            key: const ValueKey('training-day-icon'),
                            size: 44,
                            color: AppColors.textSecondary,
                          ),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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
