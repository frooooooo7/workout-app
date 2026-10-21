import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../widgets/pro_motion.dart';
import '../widgets/pro_scaffold.dart';

/// Koniec miesiąca PRO: nic nie znika, zostaje darmowy plan.
class ProTrialEndScreen extends StatelessWidget {
  const ProTrialEndScreen({super.key, this.onClose});

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

  void _stayPro(BuildContext context) {
    // Subskrypcje (Google Play Billing) nie są jeszcze gotowe.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Subskrypcje pojawią się wkrótce. Zostajesz na darmowym planie.',
        ),
      ),
    );
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
                  child: const Column(
                    children: [
                      ProHeading(
                        eyebrow: 'PRO · 30 DNI ZA TOBĄ',
                        title: 'Twój miesiąc PRO\ndobiegł końca',
                        subtitle:
                            'Wszystkie treningi i dane zostają. Przechodzisz '
                            'na darmowy plan, a PRO możesz włączyć w każdej '
                            'chwili.',
                      ),
                      SizedBox(height: 22),
                      _Comparison(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: ProReveal(
                  delay: const Duration(milliseconds: 900),
                  child: Column(
                    children: [
                      ProPrimaryButton(
                        label: 'Zostań przy PRO',
                        onPressed: () => _stayPro(context),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => _close(context),
                        style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          foregroundColor: AppColors.textSubtle,
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Kontynuuj za darmo'),
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

class _Comparison extends StatelessWidget {
  const _Comparison();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Column(
            delay: 300,
            title: 'ZOSTAJE ZA DARMO',
            color: AppColors.success,
            items: [
              'Zapisywanie treningów',
              'Kardio i superserie',
              'Masa ciała',
              'Feed i kopiowanie planów',
              '3 własne plany',
            ],
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _Column(
            delay: 450,
            title: 'W PRO',
            color: AppColors.record,
            items: [
              'Plany bez limitu',
              'Pełne wykresy i historia',
              'Rekordy i statystyki',
              'Pomiary ciała',
            ],
          ),
        ),
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.delay,
    required this.title,
    required this.color,
    required this.items,
  });

  final int delay;
  final String title;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ProReveal(
      delay: Duration(milliseconds: delay),
      child: ProCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.number(
                size: 15,
                weight: FontWeight.w700,
                color: color,
              ).copyWith(letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            for (final item in items)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
