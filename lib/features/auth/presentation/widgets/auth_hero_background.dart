import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Pełnoekranowe tło ze zdjęciem siłowni i ciemnym gradientem
/// dopasowanym do chłodnej, niebieskawej palety.
class AuthHeroBackground extends StatelessWidget {
  const AuthHeroBackground({
    super.key,
    required this.child,
    this.imageAsset = 'assets/images/login-hero.png',
  });

  final Widget child;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          imageAsset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.background.withValues(alpha: 0.45),
                AppColors.background.withValues(alpha: 0.68),
                AppColors.background.withValues(alpha: 0.86),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
