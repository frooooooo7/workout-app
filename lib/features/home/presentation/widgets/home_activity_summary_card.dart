import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'activity_stat_tile.dart';

class HomeActivitySummaryCard extends StatelessWidget {
  const HomeActivitySummaryCard({
    super.key,
    required this.workouts,
    required this.volumeKg,
    required this.caloriesKcal,
  });

  final int workouts;
  final int volumeKg;
  final int caloriesKcal;

  static String pluralWorkoutsLabel(int n) {
    if (n == 1) return 'trening';
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      return 'treningi';
    }
    return 'treningów';
  }

  static String formatCalories(int kcal) {
    if (kcal >= 1000) {
      final thousands = kcal ~/ 1000;
      final remainder = (kcal % 1000).toString().padLeft(3, '0');
      return '$thousands\u2009$remainder';
    }
    return '$kcal';
  }

  static String formatVolumeKg(int kg) {
    if (kg >= 1000) {
      final thousands = kg ~/ 1000;
      final remainder = (kg % 1000).toString().padLeft(3, '0');
      return '$thousands\u2009$remainder';
    }
    return '$kg';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Twoja aktywność',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: const Row(
                  children: [
                    Text(
                      'Zobacz statystyki',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ActivityStatTile(
                icon: Icons.fitness_center_rounded,
                iconColor: const Color(0xFF6C8EFF),
                value: '$workouts',
                label: pluralWorkoutsLabel(workouts),
                sublabel: 'w tym miesiącu',
              ),
              ActivityStatTile(
                icon: Icons.monitor_weight_rounded,
                iconColor: const Color(0xFFF59E0B),
                value: formatVolumeKg(volumeKg),
                label: 'kg',
                sublabel: 'Łączna objętość',
              ),
              ActivityStatTile(
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFFF6B35),
                value: formatCalories(caloriesKcal),
                label: 'kcal',
                sublabel: 'Spalone kalorie',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
