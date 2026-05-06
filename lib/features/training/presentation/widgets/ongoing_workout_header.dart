import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

class OngoingWorkoutHeader extends StatelessWidget {
  const OngoingWorkoutHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Przycisk wstecz
          Positioned(
            left: 16,
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context.pop(),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          
          // Środek - tytuł i stoper
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Trening',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryVariant,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '00:00:00', // TODO: Podłączyć rzeczywisty licznik czasu
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Prawa strona - Zakończ i opcje
          Positioned(
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      // TODO: Zaimplementować akcję zakończenia treningu
                    },
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      child: const Text(
                        'Zakończ',
                        style: TextStyle(
                          color: AppColors.primaryVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      // TODO: Otworzyć menu opcji treningu
                    },
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: const Icon(
                        Icons.more_horiz_rounded,
                        color: AppColors.textSecondary,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
