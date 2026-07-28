import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child, this.glass = false});

  final Widget child;

  /// Półprzezroczysta karta na tle zdjęcia (ekran powitalny logowania).
  final bool glass;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: glass ? AppColors.surfaceGlass : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: glass
              ? AppColors.border.withValues(alpha: 0.45)
              : AppColors.border,
        ),
      ),
      child: child,
    );
  }
}
