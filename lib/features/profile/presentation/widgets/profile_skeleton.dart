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
              children: const [
                SizedBox(height: AppSpacing.xs),
                SkeletonBlock(width: 96, height: 96, radius: 48),
                SizedBox(height: AppSpacing.md),
                SkeletonBlock(width: 180, height: 22),
                SizedBox(height: AppSpacing.xs),
                SkeletonBlock(width: 110, height: 14),
                SizedBox(height: AppSpacing.lg),
                SkeletonBlock(
                  height: AppSpacing.minTapTarget,
                  radius: AppRadius.md,
                ),
                SizedBox(height: AppSpacing.md),
                SkeletonBlock(height: 64, radius: AppRadius.lg),
                SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
        const ProfilePostsSkeleton(),
      ],
    );
  }
}
