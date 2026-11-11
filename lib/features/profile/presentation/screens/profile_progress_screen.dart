import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../domain/services/profile_week_calculator.dart';
import '../bloc/profile_body_cubit.dart';
import '../bloc/profile_week_cubit.dart';
import '../widgets/profile_body_shortcuts.dart';
import '../widgets/profile_details_fields.dart';
import '../widgets/profile_week_card.dart';
import 'body_measurements_screen.dart';
import 'body_weight_screen.dart';
import 'profile_details_screen.dart';

const kProfileProgressRoute = '/app/profile/progress';

/// „Postępy”: prywatne podsumowanie tygodnia, masa ciała i pomiary — to,
/// co widzi tylko właściciel profilu. Wymaga [ProfileWeekCubit]
/// i [ProfileBodyCubit] w kontekście.
class ProfileProgressScreen extends StatefulWidget {
  const ProfileProgressScreen({super.key, this.weeklyGoalLoader});

  /// Cel „ile treningów w tygodniu” z profilu (przy pracy bez sieci
  /// z lokalnej kopii). `null` — karta tygodnia zachęca do ustawienia celu.
  final Future<int?> Function()? weeklyGoalLoader;

  @override
  State<ProfileProgressScreen> createState() => _ProfileProgressScreenState();
}

class _ProfileProgressScreenState extends State<ProfileProgressScreen> {
  int? _weeklyGoal;

  @override
  void initState() {
    super.initState();
    context.read<ProfileWeekCubit>().load();
    context.read<ProfileBodyCubit>().load();
    unawaited(_loadGoal());
  }

  Future<void> _loadGoal() async {
    final loader = widget.weeklyGoalLoader;
    if (loader == null) return;
    try {
      final goal = await loader();
      if (!mounted) return;
      setState(() => _weeklyGoal = goal);
    } catch (_) {
      // Bez celu karta tygodnia po prostu o niego nie pyta.
    }
  }

  Future<void> _openGoalSettings() async {
    await context.push(kProfileDetailsRoute);
    if (!mounted) return;
    unawaited(_loadGoal());
    unawaited(context.read<ProfileWeekCubit>().load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppTabBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppHeader(
                title: 'Postępy',
                height: AppSpacing.minTapTarget,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                onBack: () => context.pop(),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: ProfileDetailsPrivacyNote(
                  key: ValueKey('progress-privacy'),
                  text: 'Widzisz to tylko Ty — inni tego nie zobaczą.',
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(
                    top: AppSpacing.md,
                    bottom:
                        AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    BlocBuilder<ProfileWeekCubit, ProfileWeekSummary?>(
                      builder: (context, summary) {
                        if (summary == null) return const SizedBox.shrink();
                        return ProfileWeekCard(
                          summary: summary,
                          weeklyGoal: _weeklyGoal,
                          onTap: () => context.push('/app/training/stats'),
                          onSetGoalTap: _openGoalSettings,
                        );
                      },
                    ),
                    BlocBuilder<ProfileBodyCubit, ProfileBodySummary?>(
                      builder: (context, summary) {
                        if (summary == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: ProfileBodyShortcuts(
                            summary: summary,
                            today: context.read<ProfileBodyCubit>().today,
                            onWeightTap: () => context.push(kBodyWeightRoute),
                            onMeasurementsTap: () =>
                                context.push(kBodyMeasurementsRoute),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
