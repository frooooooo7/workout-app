import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/training_activity_summary.dart';

class TrainingStatsScreen extends StatelessWidget {
  const TrainingStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Statystyki',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: TrainingActivitySummary(),
        ),
      ),
    );
  }
}
