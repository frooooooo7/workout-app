import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/domain/models/auth_models.dart';
import '../widgets/home_activity_summary_card.dart';
import '../widgets/home_header.dart';
import '../widgets/last_activity_card.dart';
import '../widgets/scheduled_sessions_card.dart';
import '../widgets/recent_activities_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user});

  final AuthUser user;

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
              HomeHeader(user: user),
              const SizedBox(height: 24),
              const HomeActivitySummaryCard(
                workouts: 14,
                distanceKm: 86.4,
                caloriesKcal: 6752,
              ),
              const SizedBox(height: 16),
              const ScheduledSessionsCard(),
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
