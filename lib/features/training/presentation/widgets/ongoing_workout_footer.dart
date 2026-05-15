import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class OngoingWorkoutFooter extends StatelessWidget {
  const OngoingWorkoutFooter({
    super.key,
    required this.onRestTap,
    required this.onAddExerciseTap,
    this.restLabel = 'Odpoczynek',
    this.restActive = false,
  });

  final VoidCallback onRestTap;
  final VoidCallback onAddExerciseTap;
  final String restLabel;
  final bool restActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 24, left: 32, right: 32),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFooterButton(
            icon: restActive
                ? Icons.stop_circle_outlined
                : Icons.timer_outlined,
            label: restLabel,
            onTap: onRestTap,
            highlighted: restActive,
          ),
          _buildFooterButton(
            icon: Icons.add_rounded,
            label: 'Dodaj ćwiczenie',
            onTap: onAddExerciseTap,
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: highlighted ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  color: highlighted ? Colors.white : AppColors.textSecondary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  color: highlighted
                      ? AppColors.primaryVariant
                      : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
