import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/ongoing_workout_header.dart';
import '../widgets/ongoing_workout_footer.dart';

class OngoingWorkoutScreen extends StatefulWidget {
  const OngoingWorkoutScreen({super.key});

  @override
  State<OngoingWorkoutScreen> createState() => _OngoingWorkoutScreenState();
}

class _OngoingWorkoutScreenState extends State<OngoingWorkoutScreen> {
  // TODO: Add timer logic and state variables here

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const OngoingWorkoutHeader(),
            Expanded(
              child: _buildEmptyState(),
            ),
            const OngoingWorkoutFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                color: AppColors.textMuted,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Brak ćwiczeń',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rozpocznij trening dodając swoje pierwsze ćwiczenie.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
