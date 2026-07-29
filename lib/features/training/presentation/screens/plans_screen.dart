import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/training_plans_cubit.dart';
import '../bloc/training_session_cubit.dart';
import '../widgets/training_header.dart';
import '../widgets/training_plans_tab.dart';
import 'create_plan_screen.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

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
      child: const _PlansScreenContent(),
    );
  }
}

class _PlansScreenContent extends StatelessWidget {
  const _PlansScreenContent();

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/app/training');
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  HeaderIconButton(
                    tooltip: 'Wstecz',
                    icon: Icons.arrow_back_rounded,
                    onTap: () => _handleBack(context),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Plany treningowe',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  HeaderIconButton(
                    tooltip: 'Utwórz plan',
                    icon: Icons.add_rounded,
                    isAccent: true,
                    onTap: () {
                      context.push(
                        '/app/training/create-plan',
                        extra: CreatePlanArgs(
                          cubit: context.read<TrainingPlansCubit>(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Expanded(
              child: TrainingPlansTab(),
            ),
          ],
        ),
      ),
    );
  }
}
