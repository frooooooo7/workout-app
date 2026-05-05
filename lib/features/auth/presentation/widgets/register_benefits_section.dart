import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class RegisterBenefitsSection extends StatelessWidget {
  const RegisterBenefitsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dlaczego warto?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16),
          RegisterBenefitItem(
            icon: Icons.trending_up_rounded,
            iconColor: Color(0xFF6C47FF),
            title: 'Pełna analiza progresu',
            description: 'Śledź swoje wyniki i bicie rekordów.',
          ),
          SizedBox(height: 14),
          RegisterBenefitItem(
            icon: Icons.local_fire_department_rounded,
            iconColor: Color(0xFFFF6B35),
            title: 'Motywacja każdego dnia',
            description: 'Osiągaj cele i utrzymuj streaki.',
          ),
          SizedBox(height: 14),
          RegisterBenefitItem(
            icon: Icons.people_outline_rounded,
            iconColor: Color(0xFF22C55E),
            title: 'Społeczność, która napędza',
            description: 'Rywalizuj, dziel się wynikami i inspiruj innych.',
          ),
        ],
      ),
    );
  }
}

class RegisterBenefitItem extends StatelessWidget {
  const RegisterBenefitItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
