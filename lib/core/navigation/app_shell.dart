import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/models/auth_models.dart';
import '../../features/training/presentation/bloc/training_session_cubit.dart';
import '../../features/training/presentation/screens/ongoing_workout_screen.dart';
import '../theme/app_colors.dart';
import 'app_bottom_nav.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.user,
  });

  /// Branch index of the center "Trening" tab.
  static const int trainingBranchIndex = 2;

  final StatefulNavigationShell navigationShell;
  final AuthUser user;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _handleCenterTap(
    BuildContext context,
    TrainingSessionState sessionState,
  ) {
    final active = sessionState.activeSession;
    if (active == null) {
      _onDestinationSelected(trainingBranchIndex);
      return;
    }
    final cubit = context.read<TrainingSessionCubit>();
    context
        .push(
          '/app/training/ongoing-workout',
          extra: OngoingWorkoutArgs(
            initialSession: active,
            sessionCubit: cubit,
          ),
        )
        .then((_) => cubit.refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar:
          BlocBuilder<TrainingSessionCubit, TrainingSessionState>(
            builder: (context, sessionState) {
              return AppBottomNav(
                currentIndex: navigationShell.currentIndex,
                hasActiveSession: sessionState.activeSession != null,
                onDestinationSelected: _onDestinationSelected,
                onCenterTap: () => _handleCenterTap(context, sessionState),
              );
            },
          ),
    );
  }
}
