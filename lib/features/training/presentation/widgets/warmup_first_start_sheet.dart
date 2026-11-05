import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

const warmupFirstStartYesKey = ValueKey('warmup-first-yes');
const warmupFirstStartNoKey = ValueKey('warmup-first-no');

/// Pytanie przy pierwszym starcie treningu: czy zaczynać od rozgrzewki.
/// `true` — tak, `false` — nie, `null` — zamknięto bez wyboru (nic się nie
/// zapisuje, zapytamy przy następnym starcie).
Future<bool?> showWarmupFirstStartSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    useSafeArea: true,
    // Nad dolnym paskiem, jak ekran pytania w makiecie.
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _WarmupFirstStartSheet(),
  );
}

class _WarmupFirstStartSheet extends StatelessWidget {
  const _WarmupFirstStartSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageGutter,
          12,
          AppSpacing.pageGutter,
          AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ROZGRZEWKA',
              style: TextStyle(
                color: AppColors.primaryVariant,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Zaczynasz od rozgrzewki?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Przed treningiem otworzymy panel ze stoperem. Rozgrzewasz się '
              'po swojemu, a aplikacja mierzy czas. Gdy skończysz, stukniesz '
              '„Rozpocznij trening”.',
              style: TextStyle(
                color: AppColors.textSubtle,
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            const _Point(
              icon: Icons.timer_outlined,
              title: 'Stoper z celem czasu',
              subtitle: 'domyślnie 8 min, zmienisz w Ustawieniach',
            ),
            const SizedBox(height: 8),
            const _Point(
              icon: Icons.schedule_rounded,
              title: 'Zegar treningu rusza po rozgrzewce',
              subtitle: 'rozgrzewka nie wlicza się do czasu treningu',
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: warmupFirstStartYesKey,
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(56),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('Tak, zaczynam od rozgrzewki'),
            ),
            const SizedBox(height: 4),
            TextButton(
              key: warmupFirstStartNoKey,
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSubtle,
                minimumSize: const Size.fromHeight(48),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Nie, od razu trening'),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.settings_outlined,
                    color: AppColors.primaryVariant,
                    size: 22,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          color: AppColors.textSubtle,
                          fontSize: 13,
                          height: 1.35,
                        ),
                        children: [
                          TextSpan(text: 'Zmienisz to w każdej chwili: '),
                          TextSpan(
                            text:
                                'Profil → Ustawienia → Rozgrzewka przed '
                                'treningiem',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryVariant, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
