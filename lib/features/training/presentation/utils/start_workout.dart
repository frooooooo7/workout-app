import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/custom_training_plan.dart';
import '../../domain/models/training_session.dart';
import '../bloc/training_session_cubit.dart';
import '../screens/ongoing_workout_screen.dart';

/// Rozpoczyna trening z [plan] i otwiera ekran trwającej sesji.
/// Szczegóły zachowania — [startWorkout].
Future<bool> startPlanWorkout(
  BuildContext context,
  CustomTrainingPlan plan, {
  bool replace = false,
}) {
  return startWorkout(
    context,
    start: (cubit) => cubit.startFromPlan(plan),
    replace: replace,
  );
}

/// Wspólny przepływ startu treningu: [start] tworzy sesję przez
/// [TrainingSessionCubit] z kontekstu. Gdy trwa już inna sesja, pokazuje
/// komunikat i otwiera ją zamiast nowej.
///
/// [replace] podmienia bieżący ekran (ekrany wyboru); w przeciwnym razie
/// czeka na zamknięcie ekranu sesji i odświeża cubit. Zwraca `true`, jeśli
/// ekran sesji został otwarty.
Future<bool> startWorkout(
  BuildContext context, {
  required Future<TrainingSession?> Function(TrainingSessionCubit cubit) start,
  bool replace = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final sessionCubit = context.read<TrainingSessionCubit>();
  final session = await start(sessionCubit);
  if (!context.mounted) return false;

  final target = session ?? sessionCubit.state.activeConflict;
  if (session == null) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Masz już aktywną sesję — wznawiam obecny trening.'),
      ),
    );
  }
  if (target == null) return false;

  const route = '/app/training/ongoing-workout';
  final args = OngoingWorkoutArgs(
    initialSession: target,
    sessionCubit: sessionCubit,
  );
  if (replace) {
    context.pushReplacement(route, extra: args);
    return true;
  }
  await context.push(route, extra: args);
  if (context.mounted) sessionCubit.refresh();
  return true;
}
