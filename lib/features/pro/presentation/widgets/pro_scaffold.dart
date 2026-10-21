import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'pro_motion.dart';

const proBackgroundAsset = 'assets/images/pro_background.webp';

/// Tło ekranów PRO: ciemny granat z kolorowymi poświatami, ledwo dryfujące.
class ProBackground extends StatefulWidget {
  const ProBackground({super.key, required this.child});

  final Widget child;

  @override
  State<ProBackground> createState() => _ProBackgroundState();
}

class _ProBackgroundState extends State<ProBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _drift,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _drift.value * 14),
              child: child,
            ),
            child: Transform.scale(
              scale: 1.04,
              child: Image.asset(
                proBackgroundAsset,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// Złota etykieta nad nagłówkiem, np. `PRO · 30 DNI ZA DARMO`.
class ProEyebrow extends StatelessWidget {
  const ProEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AppTextStyles.number(
        size: 17,
        weight: FontWeight.w700,
        color: AppColors.record,
      ).copyWith(letterSpacing: 2.4),
    );
  }
}

/// Nagłówek ekranu PRO: etykieta, tytuł i opis, wchodzące razem.
class ProHeading extends StatelessWidget {
  const ProHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ProReveal(
      delay: const Duration(milliseconds: 100),
      child: Column(
        children: [
          ProEyebrow(eyebrow),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.6,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSubtle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Półprzezroczysta karta na kolorowym tle.
class ProCard extends StatelessWidget {
  const ProCard({super.key, required this.child, this.padding = 14});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
  }
}

/// Główny przycisk ekranów PRO z delikatnie pulsującą poświatą.
class ProPrimaryButton extends StatefulWidget {
  const ProPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  State<ProPrimaryButton> createState() => _ProPrimaryButtonState();
}

class _ProPrimaryButtonState extends State<ProPrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      Future<void>.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) _pulse.repeat();
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45 * (1 - t)),
                spreadRadius: 8 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: widget.onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}
