import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ProfileEmptyState extends StatelessWidget {
  const ProfileEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onActionTap,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 32),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (actionLabel != null && onActionTap != null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: onActionTap,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
