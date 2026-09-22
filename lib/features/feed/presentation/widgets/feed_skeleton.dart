import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/skeleton.dart';

/// Szkielet listy postów na czas pierwszego wczytania.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      label: 'Wczytywanie feedu',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const _SkeletonStrip(),
          const SizedBox(height: 14),
          for (var i = 0; i < count; i++)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: _SkeletonCard(),
            ),
        ],
      ),
    );
  }
}

class _SkeletonStrip extends StatelessWidget {
  const _SkeletonStrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(width: 20),
        itemBuilder: (_, _) => const Column(
          children: [
            SizedBox(height: 2),
            SkeletonBlock(width: 54, height: 54, radius: 18),
            SizedBox(height: 8),
            SkeletonBlock(width: 40, height: 9),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBlock(width: 54, height: 54, radius: 18),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBlock(width: 120, height: 12),
                  SizedBox(height: 6),
                  SkeletonBlock(width: 80, height: 10),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          SkeletonBlock(width: 170, height: 16),
          SizedBox(height: 16),
          SkeletonBlock(height: 64, radius: 16),
          SizedBox(height: 16),
          SkeletonBlock(height: 11),
          SizedBox(height: 7),
          SkeletonBlock(width: 220, height: 11),
          SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: SkeletonBlock(height: 42, radius: 21)),
              SizedBox(width: 8),
              Expanded(child: SkeletonBlock(height: 42, radius: 21)),
            ],
          ),
        ],
      ),
    );
  }
}
