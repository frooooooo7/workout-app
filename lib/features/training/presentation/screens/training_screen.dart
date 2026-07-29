import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/training_plans_cubit.dart';
import '../bloc/training_session_cubit.dart';
import '../widgets/training_header.dart';
import '../widgets/training_session_tab.dart';
import 'ongoing_workout_screen.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          TrainingPlansCubit(ServiceLocator.trainingPlanRepository),
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (!identical(_router, router)) {
      _router?.routerDelegate.removeListener(_onRouteStackChanged);
      _router = router;
      _router!.routerDelegate.addListener(_onRouteStackChanged);
    }
  }

  void _onRouteStackChanged() {
    if (!mounted) return;
    final path = _router?.state.uri.path;
    if (path == '/app/training') {
      context.read<TrainingSessionCubit>().refresh();
      context.read<TrainingPlansCubit>().refresh();
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: BlocBuilder<TrainingSessionCubit, TrainingSessionState>(
                builder: (context, sessionState) {
                  final active = sessionState.activeSession;
                  return TrainingHeader(
                    activePlanName: active?.planName,
                    onActiveTap: active == null
                        ? null
                        : () {
                            final cubit = context
                                .read<TrainingSessionCubit>();
                            context
                                .push(
                                  '/app/training/ongoing-workout',
                                  extra: OngoingWorkoutArgs(
                                    initialSession: active,
                                    sessionCubit: cubit,
                                  ),
                                )
                                .then((_) {
                                  if (context.mounted) cubit.refresh();
                                });
                          },
                    onLibraryTap: () {
                      context.push('/app/training/library');
                    },
                    onAddTap: () {
                      context.push('/app/training/pick-activity-type');
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            const Expanded(
              child: TrainingSessionTab(),
            ),
          ],
        ),
      ),
    );
  }
}
