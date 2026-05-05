import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class LoginFeatureRow extends StatelessWidget {
  const LoginFeatureRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        LoginFeatureItem(
          icon: Icons.fitness_center_outlined,
          label: 'Zapisuj\ntreningi',
        ),
        SizedBox(width: 28),
        LoginFeatureItem(
          icon: Icons.trending_up_rounded,
          label: 'Analizuj\nprogres',
        ),
        SizedBox(width: 28),
        LoginFeatureItem(
          icon: Icons.people_outline_rounded,
          label: 'Rywalizuj\nz innymi',
        ),
      ],
    );
  }
}

class LoginFeatureItem extends StatelessWidget {
  const LoginFeatureItem({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
