import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/units/weight_unit.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../profile/domain/repositories/body_weight_repository.dart';
import '../../domain/repositories/training_stats_repository.dart';
import '../bloc/training_stats_cubit.dart';
import '../bloc/weekly_goal_source.dart';
import '../widgets/stats/training_stats_view.dart';

/// Statystyki jako osobny ekran: pulpit z kartami. Wejście z ikony wykresu w
/// nagłówku Historii i z Profilu.
class TrainingStatsScreen extends StatelessWidget {
  const TrainingStatsScreen({
    super.key,
    this.repository,
    this.dataChanges,
    this.clock,
    this.weeklyGoalLoader,
    this.bodyWeightRepository,
    this.sharedCubit,
  });

  /// Cubit Historii, gdy wejście jest stamtąd: sesje i rekordy są już
  /// wczytane, więc ekran ich nie czyta i nie liczy drugi raz. Bez niego
  /// (Profil, link) ekran tworzy własny.
  final TrainingStatsCubit? sharedCubit;

  /// Test seam; domyślnie [ServiceLocator.trainingStatsRepository].
  final TrainingStatsRepository? repository;

  /// Test seam; domyślnie [ServiceLocator.trainingSessionDataChanges].
  final Listenable? dataChanges;
  final DateTime Function()? clock;

  /// Test seam; domyślnie cel z profilu ([loadOwnWeeklyGoal]).
  final Future<int?> Function()? weeklyGoalLoader;

  /// Karta „Masa ciała”; router podaje [ServiceLocator.bodyWeightRepository],
  /// testy mogą ją pominąć.
  final BodyWeightRepository? bodyWeightRepository;

  @override
  Widget build(BuildContext context) {
    final shared = sharedCubit;
    if (shared != null) {
      return BlocProvider.value(value: shared, child: _scaffold(context));
    }
    return BlocProvider(
      create: (_) => TrainingStatsCubit(
        repository ?? ServiceLocator.trainingStatsRepository,
        dataChanges:
            dataChanges ??
            Listenable.merge([
              ServiceLocator.trainingSessionDataChanges,
              WeightUnits.notifier,
            ]),
        clock: clock,
        weeklyGoalLoader: weeklyGoalLoader ?? loadOwnWeeklyGoal,
      )..load(),
      child: _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    return Scaffold(
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
              Expanded(
                child: TrainingStatsView(
                  onStartWorkout: () => context.go('/app/training'),
                  bodyWeightRepository: bodyWeightRepository,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
