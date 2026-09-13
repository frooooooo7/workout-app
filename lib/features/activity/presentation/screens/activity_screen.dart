import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/sync_status_indicator.dart';
import '../widgets/activity_summary_card.dart';
import '../widgets/last_activity_card.dart';
import '../widgets/recent_activities_card.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aktywność',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Podsumowanie ostatnich treningów siłowych.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  SyncStatusIndicator(),
                ],
              ),
              const SizedBox(height: 24),
              const ActivitySummaryCard(
                workouts: 14,
                volumeKg: 86400,
                caloriesKcal: 6752,
              ),
              const SizedBox(height: 16),
              LastActivityCard(activity: LastActivityCard.mock),
              const SizedBox(height: 16),
              const RecentActivitiesCard(),
            ],
          ),
        ),
      ),
    );
  }
}
