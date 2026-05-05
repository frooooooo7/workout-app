import 'package:flutter/material.dart';
import 'login_feature_row.dart';
import 'login_hero_text.dart';
import 'login_logo_badge.dart';
import 'login_smoke_animation.dart';

class LoginHeroSection extends StatelessWidget {
  const LoginHeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.56;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/login-hero.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xB3000000),
                    Color(0xE6000000),
                  ],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: LoginSmokeAnimation()),
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    LoginLogoBadge(),
                    SizedBox(height: 32),
                    LoginHeroText(),
                    SizedBox(height: 24),
                    LoginFeatureRow(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
