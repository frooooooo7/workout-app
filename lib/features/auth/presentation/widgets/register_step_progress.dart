import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class RegisterStepProgress extends StatelessWidget {
  const RegisterStepProgress({
    super.key,
    required this.currentStep,
    this.stepCount = 2,
  });

  final int currentStep;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(stepCount, (index) {
        final isActive = index <= currentStep;
        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: index < stepCount - 1 ? 6 : 0),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
