import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/repositories/training_stats_repository.dart';
import '../bloc/training_summary_cubit.dart';
import '../widgets/training_activity_summary.dart';

class TrainingStatsScreen extends StatelessWidget {
  const TrainingStatsScreen({
    super.key,
    this.repository,
    this.dataChanges,
    this.clock,
  });

  /// Test seam; domyślnie [ServiceLocator.trainingStatsRepository].
  final TrainingStatsRepository? repository;

  /// Test seam; domyślnie [ServiceLocator.trainingSessionDataChanges].
  final Listenable? dataChanges;
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TrainingSummaryCubit(
        repository ?? ServiceLocator.trainingStatsRepository,
        dataChanges: dataChanges ?? ServiceLocator.trainingSessionDataChanges,
        clock: clock,
      )..load(),
      child: Scaffold(
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
      ),
    );
  }
}
