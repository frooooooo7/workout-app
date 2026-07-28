import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/auth_card.dart';
import '../widgets/auth_hero_background.dart';
import '../widgets/login_welcome_card.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AuthHeroBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: AuthCard(
                glass: true,
                child: LoginWelcomeCard(
                  onLoginPressed: () => context.push('/login/form'),
                  onRegisterPressed: () => context.push('/login/register'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
