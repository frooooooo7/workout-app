import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class RegisterScreenHeader extends StatelessWidget {
  const RegisterScreenHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Utwórz konto',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Zacznij swoją drogę do lepszej wersji siebie.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
