import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/widgets/home_activity_summary_card.dart';
import '../../../home/presentation/widgets/last_activity_card.dart';
import '../../../home/presentation/widgets/recent_activities_card.dart';

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
              const Text(
                'Aktywność',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Podsumowanie ostatnich treningów i ruchu.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              const HomeActivitySummaryCard(
                workouts: 14,
                distanceKm: 86.4,
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
