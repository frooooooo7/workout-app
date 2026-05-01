import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';

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
            _HeroSection(),
            _BottomSection(context),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.56;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          // 1. Zdjęcie tła
          Positioned.fill(
            child: Image.asset(
              'assets/images/login-hero.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),

          // 2. Czarny gradient overlay top→bottom
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xB3000000), // rgba(0,0,0,0.7)
                    Color(0xE6000000), // rgba(0,0,0,0.9)
                  ],
                ),
              ),
            ),
          ),

          // 3. Animacja smoke/parallax
          const Positioned.fill(child: _SmokeAnimation()),

          // 4. Treść – wycentrowana
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _LogoBadge(),
                    const SizedBox(height: 32),
                    _HeroText(),
                    const SizedBox(height: 24),
                    _FeatureRow(),
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

// ---------------------------------------------------------------------------
// Smoke / parallax animation
// ---------------------------------------------------------------------------

class _SmokeAnimation extends StatefulWidget {
  const _SmokeAnimation();

  @override
  State<_SmokeAnimation> createState() => _SmokeAnimationState();
}

class _SmokeAnimationState extends State<_SmokeAnimation>
    with TickerProviderStateMixin {
  late final List<_SmokeParticle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(42);
    _particles = List.generate(6, (i) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(seconds: 8 + rng.nextInt(6)),
      )..repeat(reverse: true);

      final driftController = AnimationController(
        vsync: this,
        duration: Duration(seconds: 12 + rng.nextInt(8)),
      )..repeat(reverse: true);

      return _SmokeParticle(
        controller: controller,
        driftController: driftController,
        startX: rng.nextDouble(),
        startY: rng.nextDouble() * 0.6,
        size: 180.0 + rng.nextDouble() * 140,
        opacity: 0.04 + rng.nextDouble() * 0.06,
        driftX: (rng.nextDouble() - 0.5) * 0.12,
        driftY: (rng.nextDouble() - 0.5) * 0.08,
      );
    });
  }

  @override
  void dispose() {
    for (final p in _particles) {
      p.controller.dispose();
      p.driftController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: _particles
              .map((p) => _AnimatedSmokeBlob(
                    particle: p,
                    maxWidth: constraints.maxWidth,
                    maxHeight: constraints.maxHeight,
                  ))
              .toList(),
        );
      },
    );
  }
}

class _SmokeParticle {
  _SmokeParticle({
    required this.controller,
    required this.driftController,
    required this.startX,
    required this.startY,
    required this.size,
    required this.opacity,
    required this.driftX,
    required this.driftY,
  });

  final AnimationController controller;
  final AnimationController driftController;
  final double startX;
  final double startY;
  final double size;
  final double opacity;
  final double driftX;
  final double driftY;
}

class _AnimatedSmokeBlob extends StatelessWidget {
  const _AnimatedSmokeBlob({
    required this.particle,
    required this.maxWidth,
    required this.maxHeight,
  });

  final _SmokeParticle particle;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([particle.controller, particle.driftController]),
      builder: (context, _) {
        final t = particle.controller.value;
        final d = particle.driftController.value;

        final x = (particle.startX + particle.driftX * d) * maxWidth - particle.size / 2;
        final y = (particle.startY + particle.driftY * t) * maxHeight - particle.size / 2;
        final scale = 0.85 + t * 0.3;

        return Positioned(
          left: x,
          top: y,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: particle.size,
              height: particle.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: particle.opacity),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Logo badge – wycentrowane
// ---------------------------------------------------------------------------

class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: 72,
          height: 72,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        const SizedBox(height: 10),
        const Text(
          'STRONGER',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'TRAIN. TRACK. EVOLVE.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero text – wycentrowany
// ---------------------------------------------------------------------------

class _HeroText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Trenuj mądrze.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryVariant],
          ).createShader(bounds),
          child: const Text(
            'Osiągaj więcej.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Śledź swoje treningi, analizuj progres\ni osiągaj kolejne cele.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Feature row – wycentrowany
// ---------------------------------------------------------------------------

class _FeatureRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _FeatureItem(icon: Icons.fitness_center_outlined, label: 'Zapisuj\ntreningi'),
        SizedBox(width: 28),
        _FeatureItem(icon: Icons.trending_up_rounded, label: 'Analizuj\nprogres'),
        SizedBox(width: 28),
        _FeatureItem(icon: Icons.people_outline_rounded, label: 'Rywalizuj\nz innymi'),
      ],
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom section
// ---------------------------------------------------------------------------

class _BottomSection extends StatelessWidget {
  const _BottomSection(this.context);

  final BuildContext context;

  void _handleLoginTap() {
    context.push('/login/form');
  }

  void _handleRegisterTap() {
    context.push('/login/register');
  }

  @override
  Widget build(BuildContext outerContext) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: _handleLoginTap,
            child: const Text('Zaloguj się'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _handleRegisterTap,
            child: const Text('Utwórz konto'),
          ),
          const SizedBox(height: 28),
          _SocialDivider(),
          const SizedBox(height: 20),
          _SocialButtons(),
          const SizedBox(height: 28),
          _TermsText(),
        ],
      ),
    );
  }
}

class _SocialDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'lub kontynuuj z',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

class _SocialButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SocialButton(icon: Icons.apple, label: '')),
        const SizedBox(width: 12),
        Expanded(child: _SocialButton(icon: Icons.g_mobiledata_rounded, label: '')),
        const SizedBox(width: 12),
        Expanded(child: _SocialButton(icon: Icons.facebook_rounded, label: '')),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Icon(icon, color: AppColors.textPrimary, size: 26),
    );
  }
}

class _TermsText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
        children: [
          TextSpan(text: 'Kontynuując, akceptujesz nasz '),
          TextSpan(
            text: 'Regulamin',
            style: TextStyle(color: AppColors.primary),
          ),
          TextSpan(text: '\noraz '),
          TextSpan(
            text: 'Politykę prywatności',
            style: TextStyle(color: AppColors.primary),
          ),
          TextSpan(text: '.'),
        ],
      ),
    );
  }
}
