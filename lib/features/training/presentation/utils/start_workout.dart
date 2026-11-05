import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/custom_training_plan.dart';
import '../../domain/models/training_session.dart';
import '../bloc/training_session_cubit.dart';
import '../screens/ongoing_workout_screen.dart';
import 'warmup_gate.dart';

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
    warmup: WarmupRequest.plan(plan),
  );
}

/// Wspólny przepływ startu treningu: [start] tworzy sesję przez
/// [TrainingSessionCubit] z kontekstu. Gdy trwa już inna sesja, pokazuje
/// komunikat i otwiera ją zamiast nowej.
///
/// [replace] podmienia bieżący ekran (ekrany wyboru); w przeciwnym razie
/// czeka na zamknięcie ekranu sesji i odświeża cubit. Zwraca `true`, jeśli
/// ekran sesji został otwarty.
///
/// Gdy podano [warmup], przed utworzeniem sesji działa bramka rozgrzewki
/// ([runWarmupGate]): pytanie przy pierwszym starcie albo panel ze stoperem.
/// Zegar treningu rusza dopiero po „Rozpocznij trening”.
Future<bool> startWorkout(
  BuildContext context, {
  required Future<TrainingSession?> Function(TrainingSessionCubit cubit) start,
  bool replace = false,
  WarmupRequest? warmup,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final sessionCubit = context.read<TrainingSessionCubit>();
  int? warmupSeconds;
  if (warmup != null) {
    final gate = await runWarmupGate(
      context,
      warmup,
      sessionInProgress: sessionCubit.state.activeSession != null,
    );
    if (!gate.proceed || !context.mounted) return false;
    warmupSeconds = gate.seconds;
  }
  var session = await start(sessionCubit);
  if (session != null) {
    session = await attachWarmupSeconds(sessionCubit, session, warmupSeconds);
  }
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

/// Zapisuje przy świeżo utworzonej [session] czas rozgrzewki ([seconds] z
/// bramki). Bez czasu nic nie robi. Błąd zapisu nie przerywa startu treningu,
/// rozgrzewka po prostu nie trafi do historii.
Future<TrainingSession> attachWarmupSeconds(
  TrainingSessionCubit cubit,
  TrainingSession session,
  int? seconds,
) async {
  if (seconds == null) return session;
  final withWarmup = session.copyWith(warmupSeconds: seconds);
  try {
    await cubit.save(withWarmup);
    return withWarmup;
  } catch (_) {
    return session;
  }
}

/// Po wyjściu z ekranu wolnego treningu: pusta sesja bez planu i bez
/// żadnego ćwiczenia nie ma czego zachować, a jako „trwająca” blokowałaby
/// start kolejnych — więc jest anulowana. Zwraca `true`, gdy ją anulowano.
Future<bool> discardEmptyCustomSession(TrainingSessionCubit cubit) async {
  await cubit.refresh();
  final active = cubit.state.activeSession;
  if (active == null ||
      active.planLocalId != null ||
      active.planServerId != null ||
      active.exercises.isNotEmpty) {
    return false;
  }
  await cubit.cancel(active.id);
  return true;
}
