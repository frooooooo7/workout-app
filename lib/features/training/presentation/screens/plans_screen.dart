import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../bloc/training_plans_cubit.dart';
import '../widgets/training_plans_tab.dart';
import 'create_plan_screen.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TrainingPlansCubit(
        ServiceLocator.trainingPlanRepository,
        dataChanges: ServiceLocator.trainingPlanDataChanges,
      ),
      child: const _PlansScreenContent(),
    );
  }
}

class _PlansScreenContent extends StatelessWidget {
  const _PlansScreenContent();

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
              AppTabHeader(
                title: 'Plany treningowe',
                actions: [
                  AppTabHeaderButton(
                    tooltip: 'Utwórz plan',
                    icon: Icons.add_rounded,
                    accent: true,
                    onPressed: () {
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
              const SizedBox(height: AppSpacing.sm),
              const Expanded(child: TrainingPlansTab()),
            ],
          ),
        ),
      ),
    );
  }
}
