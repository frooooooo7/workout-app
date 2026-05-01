import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/onboarding_data.dart';
import '../../../../core/theme/app_colors.dart';

class OnboardingWelcomeScreen extends StatefulWidget {
  const OnboardingWelcomeScreen({super.key, required this.data});

  final OnboardingData data;

  @override
  State<OnboardingWelcomeScreen> createState() =>
      _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends State<OnboardingWelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _checkController;
  late final AnimationController _fadeController;
  late final AnimationController _confettiController;

  late final Animation<double> _checkScale;
  late final Animation<double> _fadeAnim;

  final List<_ConfettiParticle> _particles = [];

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _checkScale = CurvedAnimation(
      parent: _checkController,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    final rng = math.Random();
    _particles.addAll(List.generate(40, (_) => _ConfettiParticle(rng)));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _checkController.forward();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _fadeController.forward();
      _confettiController.forward();
    });
  }

  @override
  void dispose() {
    _checkController.dispose();
    _fadeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    // TODO: navigate to dashboard / main app
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Confetti layer
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _confettiController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ConfettiPainter(
                    particles: _particles,
                    progress: _confettiController.value,
                    size: size,
                  ),
                );
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),

                  // Check icon
                  Center(
                    child: ScaleTransition(
                      scale: _checkScale,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              blurRadius: 40,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 52,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      children: const [
                        Text(
                          'Twój profil\njest gotowy!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Zadbaliśmy o wszystko. Czas zacząć\ntrenować i osiągać kolejne cele.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  FadeTransition(
                    opacity: _fadeAnim,
                    child: _SummaryCard(data: widget.data),
                  ),

                  const Spacer(flex: 3),

                  FadeTransition(
                    opacity: _fadeAnim,
                    child: ElevatedButton(
                      onPressed: _handleContinue,
                      child: const Text('Przejdź do aplikacji'),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});

  final OnboardingData data;

  String get _goalLabel {
    return switch (data.fitnessGoal) {
      FitnessGoal.buildMuscle => '💪 Masa mięśniowa',
      FitnessGoal.loseWeight => '🔥 Redukcja',
      FitnessGoal.getStronger => '🏋️ Siła',
      FitnessGoal.improveEndurance => '🏃 Kondycja',
      FitnessGoal.stayHealthy => '🌿 Zdrowie',
      null => '—',
    };
  }

  String get _activityLabel {
    return switch (data.activityLevel) {
      ActivityLevel.sedentary => 'Siedzący',
      ActivityLevel.light => 'Lekko aktywny',
      ActivityLevel.moderate => 'Umiarkowanie aktywny',
      ActivityLevel.active => 'Bardzo aktywny',
      null => '—',
    };
  }

  String get _bodyLabel {
    final h = data.heightCm != null ? '${data.heightCm!.round()} cm' : '—';
    final w = data.weightKg != null ? '${data.weightKg!.round()} kg' : '—';
    return '$h · $w';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _SummaryRow(icon: Icons.flag_rounded, label: 'Cel', value: _goalLabel),
          const Divider(color: AppColors.border, height: 24),
          _SummaryRow(icon: Icons.bolt_rounded, label: 'Aktywność', value: _activityLabel),
          const Divider(color: AppColors.border, height: 24),
          _SummaryRow(
            icon: Icons.monitor_weight_outlined,
            label: 'Sylwetka',
            value: _bodyLabel,
          ),
          if (data.trainingDays.isNotEmpty) ...[
            const Divider(color: AppColors.border, height: 24),
            _SummaryRow(
              icon: Icons.calendar_today_rounded,
              label: 'Dni treningowe',
              value: '${data.trainingDays.length} dni/tydzień',
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Confetti
// ---------------------------------------------------------------------------

class _ConfettiParticle {
  _ConfettiParticle(math.Random rng)
      : x = rng.nextDouble(),
        startY = -0.1 - rng.nextDouble() * 0.2,
        speedY = 0.3 + rng.nextDouble() * 0.4,
        speedX = (rng.nextDouble() - 0.5) * 0.15,
        color = _colors[rng.nextInt(_colors.length)],
        size = 6 + rng.nextDouble() * 6,
        rotation = rng.nextDouble() * math.pi * 2,
        rotationSpeed = (rng.nextDouble() - 0.5) * 8;

  final double x;
  final double startY;
  final double speedY;
  final double speedX;
  final Color color;
  final double size;
  final double rotation;
  final double rotationSpeed;

  static const _colors = [
    Color(0xFF6C47FF),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
    Colors.white,
  ];
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.size,
  });

  final List<_ConfettiParticle> particles;
  final double progress;
  final Size size;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    for (final p in particles) {
      final opacity = (1 - (progress - 0.6).clamp(0, 0.4) / 0.4);
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      final px = (p.x + p.speedX * progress) * canvasSize.width;
      final py = (p.startY + p.speedY * progress) * canvasSize.height;
      final rot = p.rotation + p.rotationSpeed * progress;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rot);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
