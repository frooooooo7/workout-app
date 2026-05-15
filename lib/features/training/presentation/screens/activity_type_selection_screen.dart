import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/activity_type_option_tile.dart';

class ActivityTypeSelectionScreen extends StatelessWidget {
  const ActivityTypeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Nowa aktywnosc',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wybierz jak zaczynamy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dwie szybkie drogi do nowego treningu.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ActivityTypeOptionTile(
                  icon: Icons.view_week_rounded,
                  iconColor: AppColors.primaryVariant,
                  imageAsset: 'assets/images/login-hero.png',
                  imageAlignment: Alignment.centerRight,
                  eyebrow: 'Gotowy plan',
                  title: 'Moje plany',
                  description: 'Odpal zapisany program i trzymaj tempo sesji.',
                  ctaLabel: 'Wybierz plan',
                  onTap: () =>
                      context.pushReplacement('/app/training/pick-plan'),
                ),
                const SizedBox(height: 16),
                ActivityTypeOptionTile(
                  icon: Icons.bolt_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  imageAsset: 'assets/images/login-hero.png',
                  imageAlignment: Alignment.centerLeft,
                  eyebrow: 'Wolny trening',
                  title: 'Niestandardowa',
                  description: 'Zbuduj trening na biezaco, bez szablonu.',
                  ctaLabel: 'Start od zera',
                  onTap: () =>
                      context.pushReplacement('/app/training/ongoing-workout'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
