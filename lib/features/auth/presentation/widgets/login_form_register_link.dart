import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class LoginFormRegisterLink extends StatelessWidget {
  const LoginFormRegisterLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Nie masz konta? ',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        GestureDetector(
          onTap: onTap,
          child: const Text(
            'Zarejestruj się',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
