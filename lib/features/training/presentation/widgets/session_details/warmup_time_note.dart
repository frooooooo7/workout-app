import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

/// Czas rozgrzewki przed treningiem: „Rozgrzewka 8:24”. Osobno od czasu
/// treningu, więc podpis mówi, że się do niego nie wlicza.
class WarmupTimeNote extends StatelessWidget {
  const WarmupTimeNote({super.key, required this.seconds});

  final int seconds;

  static String format(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('warmup-time-note'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.local_fire_department_outlined,
          size: 15,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Rozgrzewka '),
                TextSpan(
                  text: format(seconds),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' · poza czasem treningu'),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
