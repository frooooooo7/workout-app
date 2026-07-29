import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ActivityStatTile extends StatelessWidget {
  const ActivityStatTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.sublabel,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String sublabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 10),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          sublabel,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
