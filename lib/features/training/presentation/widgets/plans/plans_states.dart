import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/skeleton.dart';

/// Brak jakiegokolwiek planu — zachęta do utworzenia pierwszego.
class PlansEmptyState extends StatelessWidget {
  const PlansEmptyState({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(AppColors.surface, AppColors.heroGlow, 0.6)!,
            AppColors.surface,
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 28,
                ),
              ],
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AppColors.primaryVariant,
              size: 28,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Zbuduj pierwszy plan',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Zapisz ćwiczenia, serie i dni tygodnia — start treningu będzie '
            'jednym tapnięciem.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                textStyle: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Utwórz plan'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wybrany dzień tygodnia nie ma żadnego planu.
class PlansDayEmptyState extends StatelessWidget {
  const PlansDayEmptyState({
    super.key,
    required this.dayName,
    required this.onCreate,
  });

  final String dayName;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.self_improvement_rounded,
            color: AppColors.textMuted,
            size: 30,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$dayName bez planu',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          const Text(
            'Dzień regeneracji — albo miejsce na nowy trening.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: onCreate,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryVariant,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Dodaj plan na ten dzień'),
          ),
        ],
      ),
    );
  }
}

/// Szkielet listy planów na czas pierwszego wczytania.
class PlansSkeleton extends StatelessWidget {
  const PlansSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      label: 'Wczytywanie planów',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SkeletonCard(height: 158),
          const SizedBox(height: AppSpacing.xl),
          const SkeletonBlock(width: 120, height: 16),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < 2; i++) ...[
            const _SkeletonCard(height: 220),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBlock(width: 160, height: 18),
          SizedBox(height: AppSpacing.xs),
          SkeletonBlock(width: 100, height: 12),
          Spacer(),
          SkeletonBlock(height: 12),
          SizedBox(height: AppSpacing.xs),
          SkeletonBlock(width: 200, height: 12),
        ],
      ),
    );
  }
}
