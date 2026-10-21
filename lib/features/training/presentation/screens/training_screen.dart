import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../auth/domain/models/auth_models.dart';
import '../../../pro/presentation/widgets/pro_trial_host.dart';
import '../bloc/training_history_cubit.dart';
import '../bloc/training_home_cubit.dart';
import '../bloc/training_plans_cubit.dart';
import '../bloc/training_session_cubit.dart';
import '../bloc/weekly_goal_source.dart';
import '../widgets/training_header.dart';
import '../widgets/training_session_tab.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => TrainingPlansCubit(
            ServiceLocator.trainingPlanRepository,
            dataChanges: ServiceLocator.trainingPlanDataChanges,
          ),
        ),
        BlocProvider(
          create: (_) => TrainingHistoryCubit(
            ServiceLocator.trainingHistoryRepository,
            dataChanges: ServiceLocator.trainingSessionDataChanges,
          ),
        ),
        BlocProvider(
          create: (_) => TrainingHomeCubit(
            ServiceLocator.trainingStatsRepository,
            dataChanges: ServiceLocator.trainingSessionDataChanges,
            weeklyGoalLoader: loadOwnWeeklyGoal,
          ),
        ),
      ],
      child: const _TrainingShellContent(),
    );
  }
}

class _TrainingShellContent extends StatefulWidget {
  const _TrainingShellContent();

  @override
  State<_TrainingShellContent> createState() => _TrainingShellContentState();
}

class _TrainingShellContentState extends State<_TrainingShellContent> {
  GoRouter? _router;
  String? _lastPath;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (!identical(_router, router)) {
      _router?.routerDelegate.removeListener(_onRouteStackChanged);
      _router = router;
      _lastPath = router.state.uri.path;
      _router!.routerDelegate.addListener(_onRouteStackChanged);
    }
  }

  void _onRouteStackChanged() {
    if (!mounted) return;
    final path = _router?.state.uri.path;
    if (path == null) return;
    final previous = _lastPath;
    _lastPath = path;
    if (previous != '/app/training' && path == '/app/training') {
      context.read<TrainingSessionCubit>().refresh();
      context.read<TrainingPlansCubit>().refresh();
      context.read<TrainingHistoryCubit>().refresh();
      context.read<TrainingHomeCubit>().refresh();
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteStackChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Bottom inset (incl. the shell's bottom nav) is left to the scroll view.
      body: AppTabBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ValueListenableBuilder<AuthUser?>(
                valueListenable: ServiceLocator.currentUser,
                builder: (context, user, _) => TrainingHeader(
                  firstName: user?.firstName,
                  onLibraryTap: () => context.push('/app/training/library'),
                ),
              ),
              const ProTrialHost(),
              const Expanded(child: TrainingSessionTab()),
            ],
          ),
        ),
      ),
    );
  }
}
