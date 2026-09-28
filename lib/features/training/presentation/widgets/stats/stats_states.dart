import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/skeleton.dart';

/// Szkielet ekranu na czas pierwszego wczytania — ten sam układ co treść.
class StatsSkeleton extends StatelessWidget {
  const StatsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget tile() => Container(
      height: 104,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.all(14),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBlock(width: 70, height: 12),
          Spacer(),
          SkeletonBlock(width: 90, height: 22),
          SizedBox(height: 8),
          SkeletonBlock(width: 60, height: 10),
        ],
      ),
    );

    return SkeletonPulse(
      label: 'Wczytywanie statystyk',
      child: Column(
        children: [
          for (var row = 0; row < 3; row++) ...[
            if (row > 0) const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(child: tile()),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: tile()),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Container(
            height: 240,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ],
      ),
    );
  }
}

/// Brak jakiegokolwiek ukończonego treningu.
class StatsEmptyState extends StatelessWidget {
  const StatsEmptyState({super.key, this.onStartWorkout});

  final VoidCallback? onStartWorkout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.insights_rounded,
              size: 30,
              color: AppColors.primaryVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Tu pojawią się Twoje statystyki',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Ukończ pierwszy trening, a zobaczysz wykresy objętości, '
            'rekordy i rozkład pracy na partie mięśni.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          if (onStartWorkout != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onStartWorkout,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Rozpocznij trening'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size(0, AppSpacing.minTapTarget),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Wybrany zakres bez treningów — historia istnieje, więc podpowiadamy
/// dłuższy zakres zamiast pustych wykresów.
class StatsEmptyRangeNotice extends StatelessWidget {
  const StatsEmptyRangeNotice({super.key, this.onShowAll});

  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_busy_rounded,
            size: 20,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text(
              'Brak treningów w tym okresie.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
            ),
          ),
          if (onShowAll != null)
            TextButton(
              onPressed: onShowAll,
              child: const Text(
                'Pokaż całość',
                style: TextStyle(
                  color: AppColors.primaryVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StatsErrorState extends StatelessWidget {
  const StatsErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Nie udało się policzyć statystyk.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Spróbuj ponownie'),
          ),
        ],
      ),
    );
  }
}
