import 'dart:math' as math;

import 'package:flutter/material.dart';

class LoginSmokeAnimation extends StatefulWidget {
  const LoginSmokeAnimation({super.key});

  @override
  State<LoginSmokeAnimation> createState() => _LoginSmokeAnimationState();
}

class _LoginSmokeAnimationState extends State<LoginSmokeAnimation>
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
              .map(
                (p) => _AnimatedSmokeBlob(
                  particle: p,
                  maxWidth: constraints.maxWidth,
                  maxHeight: constraints.maxHeight,
                ),
              )
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
      animation: Listenable.merge(
        [particle.controller, particle.driftController],
      ),
      builder: (context, _) {
        final t = particle.controller.value;
        final d = particle.driftController.value;

        final x =
            (particle.startX + particle.driftX * d) * maxWidth - particle.size / 2;
        final y =
            (particle.startY + particle.driftY * t) * maxHeight - particle.size / 2;
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
