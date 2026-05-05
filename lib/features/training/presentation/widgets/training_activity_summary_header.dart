import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class TrainingActivitySummaryHeader extends StatelessWidget {
  const TrainingActivitySummaryHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Podsumowanie aktywności',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        GestureDetector(
          onTap: () {},
          child: const Row(
            children: [
              Text(
                'Historia',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
