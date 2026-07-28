import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'auth_social_buttons_row.dart';
import 'auth_social_divider.dart';
import 'login_terms_footer.dart';

class LoginWelcomeCard extends StatelessWidget {
  const LoginWelcomeCard({
    super.key,
    required this.onLoginPressed,
    required this.onRegisterPressed,
  });

  final VoidCallback onLoginPressed;
  final VoidCallback onRegisterPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Image.asset(
            'assets/images/logo.png',
            width: 48,
            height: 48,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'STRONGER',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'TRAIN. TRACK. EVOLVE.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 9,
            letterSpacing: 2,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Trenuj mądrze.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const Text(
          'Osiągaj więcej.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Śledź swoje treningi, analizuj progres\ni osiągaj kolejne cele.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: onLoginPressed,
          child: const Text('Zaloguj się'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRegisterPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
          ),
          child: const Text('Utwórz konto'),
        ),
        const SizedBox(height: 24),
        const AuthSocialDivider(),
        const SizedBox(height: 20),
        const AuthSocialButtonsRow(),
        const SizedBox(height: 24),
        const LoginTermsFooter(),
      ],
    );
  }
}
