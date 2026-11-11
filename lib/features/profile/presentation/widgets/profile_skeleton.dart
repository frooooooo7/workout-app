import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/skeleton.dart';
import 'profile_posts_sliver.dart';

/// Szkielet profilu na czas pierwszego wczytania — ten sam układ co nagłówek,
/// więc po załadowaniu nic nie „skacze”.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        SkeletonPulse(
          label: 'Wczytywanie profilu',
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageGutter,
            ),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xs),
                const SkeletonBlock(width: 104, height: 104, radius: 52),
                const SizedBox(height: AppSpacing.sm),
                const SkeletonBlock(width: 180, height: 22),
                const SizedBox(height: AppSpacing.sm),
                const SkeletonBlock(height: 48, radius: AppRadius.md),
                const SizedBox(height: AppSpacing.md),
                const SkeletonBlock(
                  height: AppSpacing.minTapTarget,
                  radius: AppRadius.md,
                ),
                const SizedBox(height: AppSpacing.md),
                // Kółka wyróżnień.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (var i = 0; i < 4; i++)
                      const SkeletonBlock(width: 60, height: 60, radius: 30),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
        const ProfilePostsSkeleton(),
      ],
    );
  }
}
