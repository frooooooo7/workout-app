import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../domain/repositories/training_stats_repository.dart';
import '../bloc/training_stats_cubit.dart';
import '../bloc/weekly_goal_source.dart';
import '../widgets/stats/training_stats_view.dart';

/// Statystyki jako osobny ekran — wejście z Profilu. W Historii te same
/// statystyki są podzakładką.
class TrainingStatsScreen extends StatelessWidget {
  const TrainingStatsScreen({
    super.key,
    this.repository,
    this.dataChanges,
    this.clock,
    this.weeklyGoalLoader,
  });

  /// Test seam; domyślnie [ServiceLocator.trainingStatsRepository].
  final TrainingStatsRepository? repository;

  /// Test seam; domyślnie [ServiceLocator.trainingSessionDataChanges].
  final Listenable? dataChanges;
  final DateTime Function()? clock;

  /// Test seam; domyślnie cel z profilu ([loadOwnWeeklyGoal]).
  final Future<int?> Function()? weeklyGoalLoader;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TrainingStatsCubit(
        repository ?? ServiceLocator.trainingStatsRepository,
        dataChanges: dataChanges ?? ServiceLocator.trainingSessionDataChanges,
        clock: clock,
        weeklyGoalLoader: weeklyGoalLoader ?? loadOwnWeeklyGoal,
      )..load(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: AppTabBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTabHeader(
                  title: 'Statystyki',
                  showSync: false,
                  leading: AppTabHeaderButton.back(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(height: 4),
                const AppTabScrollEdge(),
                Expanded(
                  child: TrainingStatsView(
                    onStartWorkout: () => context.go('/app/training'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
