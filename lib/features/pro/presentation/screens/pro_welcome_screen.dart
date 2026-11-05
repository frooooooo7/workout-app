import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/pro_motion.dart';
import '../widgets/pro_scaffold.dart';
import '../widgets/pro_visuals.dart';

/// Powitanie po założeniu konta: miesiąc PRO za darmo i co zawiera.
/// Otwarty ponownie z paska na ekranie Trening ([info]) pokazuje ten sam
/// ekran z przyciskiem „Rozumiem”.
class ProWelcomeScreen extends StatelessWidget {
  const ProWelcomeScreen({super.key, this.info = false, this.onClose});

  final bool info;

  /// Test seam; domyślnie zamyka ekran przez router.
  final VoidCallback? onClose;

  void _close(BuildContext context) {
    if (onClose != null) {
      onClose!();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/app/training');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ProBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                  child: Column(
                    children: [
                      const ProHeading(
                        eyebrow: 'PRO · 30 DNI ZA DARMO',
                        title: 'Miesiąc pełnej wersji\nna start',
                        subtitle:
                            'Sprawdź wszystko bez karty. Po 30 dniach zostaje '
                            'darmowy plan, a Twoje dane zostają u Ciebie.',
                      ),
                      const SizedBox(height: 22),
                      const _FeatureGrid(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: ProReveal(
                  delay: const Duration(milliseconds: 1100),
                  child: Column(
                    children: [
                      ProPrimaryButton(
                        label: info ? 'Rozumiem' : 'Zaczynam',
                        onPressed: () => _close(context),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Bez zobowiązań. Nie potrzebujesz karty.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 10);
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _FeatureTile(
                  delay: 300,
                  visual: ProProgressChart(delay: Duration(milliseconds: 900)),
                  title: 'Wykresy postępu',
                  text: 'Ciężar, objętość i 1RM każdego ćwiczenia w czasie.',
                ),
              ),
              gap,
              Expanded(
                child: _FeatureTile(
                  delay: 450,
                  visual: ProRecordsBars(delay: Duration(milliseconds: 700)),
                  title: 'Rekordy i statystyki',
                  text: 'Pobite rekordy, serie tygodni i porównanie okresów.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _FeatureTile(
                  delay: 600,
                  visual: ProPlanBars(delay: Duration(milliseconds: 800)),
                  title: 'Plany bez limitu',
                  text: 'Własne kolory, ustawienia kolumn i superserie.',
                ),
              ),
              gap,
              Expanded(
                child: _FeatureTile(
                  delay: 750,
                  visual: ProMeasurementsChart(
                    delay: Duration(milliseconds: 1350),
                  ),
                  title: 'Pomiary ciała',
                  text: 'Ramię, talia, klatka i trend zmian w centymetrach.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.delay,
    required this.visual,
    required this.title,
    required this.text,
  });

  final int delay;
  final Widget visual;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ProReveal(
      delay: Duration(milliseconds: delay),
      child: ProCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            visual,
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
