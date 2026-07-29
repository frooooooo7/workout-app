import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/recent_activity.dart';

class RecentActivitiesCard extends StatelessWidget {
  const RecentActivitiesCard({super.key, this.activities});

  /// When null, sample data is shown (placeholder until API is wired).
  final List<RecentActivity>? activities;

  static List<RecentActivity> get mockActivities => const [
        RecentActivity(
          kind: RecentActivityKind.strength,
          title: 'Push — klatka i barki',
          date: 'Dziś',
          duration: '58 min',
          detail: '6 ćwiczeń',
        ),
        RecentActivity(
          kind: RecentActivityKind.strength,
          title: 'Pull — plecy i biceps',
          date: 'Wczoraj',
          duration: '52 min',
          detail: '5 ćwiczeń',
        ),
        RecentActivity(
          kind: RecentActivityKind.strength,
          title: 'Trening nóg',
          date: '29 kwi',
          duration: '1 godz 12 min',
          detail: '7 ćwiczeń',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final list = activities ?? mockActivities;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Historia treningów',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Row(
                    children: [
                      Text(
                        'Zobacz wszystkie',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: list.length,
            separatorBuilder: (context, _) =>
                const Divider(height: 1, color: AppColors.border, indent: 70),
            itemBuilder: (_, i) => RecentActivityRow(activity: list[i]),
          ),
        ],
      ),
    );
  }
}

class RecentActivityRow extends StatelessWidget {
  const RecentActivityRow({super.key, required this.activity});

  final RecentActivity activity;

  static const _visual = _ActivityVisual(
    icon: Icons.fitness_center_rounded,
    color: Color(0xFF6C8EFF),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _visual.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_visual.icon, color: _visual.color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${activity.date} · ${activity.duration}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (activity.detail != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                activity.detail!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityVisual {
  const _ActivityVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}
