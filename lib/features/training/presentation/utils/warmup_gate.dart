import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../data/warmup_stores.dart';
import '../../domain/models/custom_training_plan.dart';
import '../../domain/models/warmup.dart';
import '../../domain/services/warmup_goal_scheduler.dart';
import '../screens/warmup_screen.dart';
import '../widgets/warmup_first_start_sheet.dart';

const kWarmupRoute = '/app/training/warmup';

/// Trening, przed którym może być rozgrzewka: [target] mówi, skąd wystartował,
/// a [plan] (gdy jest) daje panelowi kartę „Po rozgrzewce”.
class WarmupRequest {
  const WarmupRequest({required this.target, this.plan});

  WarmupRequest.plan(CustomTrainingPlan plan)
    : this(
        target: WarmupTarget.plan(planId: plan.id, name: plan.name),
        plan: plan,
      );

  const WarmupRequest.custom() : this(target: const WarmupTarget.custom());

  final WarmupTarget target;
  final CustomTrainingPlan? plan;
}

/// Bramka rozgrzewki przed startem treningu. Zwraca `true`, gdy trening ma się
/// teraz zacząć (rozgrzewka wyłączona, pominięta albo skończona stuknięciem
/// „Rozpocznij trening”), `false`, gdy start przerwano (zamknięte pytanie,
/// schowany panel, „Przerwij rozgrzewkę”).
///
/// Trwający trening ([sessionInProgress]) omija bramkę — start działa jak
/// dotąd i wznawia ten trening. [navigate] podmienia otwarcie panelu (testy).
Future<bool> runWarmupGate(
  BuildContext context,
  WarmupRequest request, {
  required bool sessionInProgress,
  WarmupSettingsStore? settings,
  WarmupSessionStore? session,
  WarmupGoalScheduler? scheduler,
  Future<Object?> Function(String location, {Object? extra})? navigate,
}) async {
  if (sessionInProgress) return true;
  settings ??= ServiceLocator.warmupSettings;
  session ??= ServiceLocator.warmupSession;
  scheduler ??= ServiceLocator.warmupGoalScheduler;

  final messenger = ScaffoldMessenger.of(context);
  final push =
      navigate ??
      (String location, {Object? extra}) =>
          GoRouter.of(context).push<bool>(location, extra: extra);

  final running = session.active;
  if (running != null) {
    // Jedna rozgrzewka naraz: wracamy do niej, jeśli to ten sam trening.
    if (running.target.key != request.target.key) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Trwa rozgrzewka przed „${running.target.name}”. Wróć do niej '
            'z ekranu Trening albo ją przerwij.',
          ),
        ),
      );
      return false;
    }
  } else {
    if (settings.current.shouldAsk) {
      final choice = await showWarmupFirstStartSheet(context);
      if (choice == null) return false;
      // Wybór jest w pamięci od razu; zapis na dysk nie blokuje startu.
      unawaited(settings.setEnabled(choice));
      if (!context.mounted) return false;
    }
    if (!settings.current.isOn) return true;

    final minutes = settings.current.targetMinutes;
    unawaited(session.begin(request.target, minutes));
    unawaited(
      scheduler
          .scheduleGoalReached(after: Duration(minutes: minutes))
          .catchError((_) {}),
    );
  }

  final start = await push(
    kWarmupRoute,
    extra: WarmupArgs(request: request, session: session, scheduler: scheduler),
  );
  return start == true;
}
