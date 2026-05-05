import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class TrainingPlanDetailChip extends StatelessWidget {
  const TrainingPlanDetailChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
    );
  }
}

class TrainingPlanDetailDot extends StatelessWidget {
  const TrainingPlanDetailDot({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        '•',
        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
    );
  }
}
