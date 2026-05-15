import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/training_session_cubit.dart';
import '../screens/ongoing_workout_screen.dart';
import 'training_activity_summary.dart';
import 'training_today_plan_section.dart';

class TrainingSessionTab extends StatefulWidget {
  const TrainingSessionTab({super.key});

  @override
  State<TrainingSessionTab> createState() => _TrainingSessionTabState();
}

class _TrainingSessionTabState extends State<TrainingSessionTab> {
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now().weekday;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TrainingSessionCubit, TrainingSessionState>(
      builder: (context, sessionState) {
        final active = sessionState.activeSession;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (active != null) ...[
                _ActiveSessionCard(
                  planName: active.planName,
                  onResume: () {
                    final cubit = context.read<TrainingSessionCubit>();
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
                ),
                const SizedBox(height: 18),
              ],
              TrainingTodayPlanSection(
                selectedDay: _selectedDay,
                onDaySelected: (day) => setState(() => _selectedDay = day),
              ),
              const SizedBox(height: 24),
              const TrainingActivitySummary(),
            ],
          ),
        );
      },
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({required this.planName, required this.onResume});

  final String planName;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aktywna sesja',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  planName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onResume, child: const Text('Wznow')),
        ],
      ),
    );
  }
}
