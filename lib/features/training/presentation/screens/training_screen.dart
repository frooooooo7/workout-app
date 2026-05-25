import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/training_plans_cubit.dart';
import '../bloc/training_session_cubit.dart';
import '../widgets/training_header.dart';
import '../widgets/training_history_tab.dart';
import '../widgets/training_plans_tab.dart';
import '../widgets/training_session_tab.dart';
import 'create_plan_screen.dart';
import 'ongoing_workout_screen.dart';

enum _TrainingTab { sesja, plany, historia }

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              TrainingPlansCubit(ServiceLocator.trainingPlanRepository),
        ),
        BlocProvider(
          create: (_) =>
              TrainingSessionCubit(ServiceLocator.trainingSessionRepository),
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
  _TrainingTab _activeTab = _TrainingTab.sesja;
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BlocBuilder<TrainingSessionCubit, TrainingSessionState>(
                    builder: (context, sessionState) {
                      final active = sessionState.activeSession;
                      return TrainingHeader(
                        activePlanName: active?.planName,
                        addTooltip: _activeTab == _TrainingTab.plany
                            ? 'Utworz plan'
                            : 'Dodaj trening',
                        addLabel: _activeTab == _TrainingTab.plany
                            ? 'Dodaj plan'
                            : null,
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
                        onStatsTap: () {
                          context.push('/app/training/stats');
                        },
                        onAddTap: () {
                          if (_activeTab == _TrainingTab.plany) {
                            context.push(
                              '/app/training/create-plan',
                              extra: CreatePlanArgs(
                                cubit: context.read<TrainingPlansCubit>(),
                              ),
                            );
                            return;
                          }

                          context.push('/app/training/pick-activity-type');
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _TrainingTabBar(
                    active: _activeTab,
                    onTabSelected: (tab) => setState(() => _activeTab = tab),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: switch (_activeTab) {
                _TrainingTab.sesja => const TrainingSessionTab(),
                _TrainingTab.plany => const TrainingPlansTab(),
                _TrainingTab.historia => const TrainingHistoryTab(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainingTabBar extends StatelessWidget {
  const _TrainingTabBar({required this.active, required this.onTabSelected});

  final _TrainingTab active;
  final ValueChanged<_TrainingTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: _TrainingTab.values
            .map(
              (tab) => _TrainingTabItem(
                tab: tab,
                isActive: tab == active,
                onTap: () => onTabSelected(tab),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TrainingTabItem extends StatelessWidget {
  const _TrainingTabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final _TrainingTab tab;
  final bool isActive;
  final VoidCallback onTap;

  String get _label => switch (tab) {
    _TrainingTab.sesja => 'Sesja',
    _TrainingTab.plany => 'Plany',
    _TrainingTab.historia => 'Historia',
  };

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isActive ? AppColors.surfaceVariant : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: isActive ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(_label),
          ),
        ),
      ),
    );
  }
}
