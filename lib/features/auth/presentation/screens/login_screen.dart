import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/login_bottom_section.dart';
import '../widgets/login_hero_section.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LoginHeroSection(),
            LoginBottomSection(
              onPrimaryPressed: () => context.push('/login/form'),
              onSecondaryPressed: () => context.push('/login/register'),
            ),
          ],
        ),
      ),
    );
  }
}
