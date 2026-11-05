import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/service_locator.dart';
import '../../data/warmup_stores.dart';
import '../../domain/models/custom_training_plan.dart';
import '../../domain/models/warmup.dart';
import '../../domain/repositories/training_plan_repository.dart';
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

/// Wynik bramki rozgrzewki: [proceed] — czy zaczynać trening, [seconds] —
/// zmierzony czas rozgrzewki do zapisania przy sesji (`null` — bez rozgrzewki,
/// krótsza niż minuta albo nieznany).
class WarmupGateResult {
  const WarmupGateResult.go({this.seconds}) : proceed = true;

  const WarmupGateResult.stop() : proceed = false, seconds = null;

  final bool proceed;
  final int? seconds;
}

/// Bramka rozgrzewki przed startem treningu. Zwraca `true`, gdy trening ma się
/// teraz zacząć (rozgrzewka wyłączona, pominięta albo skończona stuknięciem
/// „Rozpocznij trening”), `false`, gdy start przerwano (zamknięte pytanie,
/// schowany panel, „Przerwij rozgrzewkę”).
///
/// Trwający trening ([sessionInProgress]) omija bramkę — start działa jak
/// dotąd i wznawia ten trening. [navigate] podmienia otwarcie panelu (testy).
Future<WarmupGateResult> runWarmupGate(
  BuildContext context,
  WarmupRequest request, {
  required bool sessionInProgress,
  WarmupSettingsStore? settings,
  WarmupSessionStore? session,
  WarmupGoalScheduler? scheduler,
  Future<Object?> Function(String location, {Object? extra})? navigate,
}) async {
  if (sessionInProgress) return const WarmupGateResult.go();
  settings ??= ServiceLocator.warmupSettings;
  session ??= ServiceLocator.warmupSession;
  scheduler ??= ServiceLocator.warmupGoalScheduler;

  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.maybeOf(context);
  final push =
      navigate ??
      (String location, {Object? extra}) =>
          GoRouter.of(context).push<Object>(location, extra: extra);

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
          action: router == null
              ? null
              : SnackBarAction(
                  label: 'Wróć',
                  onPressed: () => router.go('/app/training'),
                ),
        ),
      );
      return const WarmupGateResult.stop();
    }
  } else {
    if (settings.current.shouldAsk) {
      final choice = await showWarmupFirstStartSheet(context);
      if (choice == null) return const WarmupGateResult.stop();
      // Wybór jest w pamięci od razu; zapis na dysk nie blokuje startu.
      unawaited(settings.setEnabled(choice));
      if (!context.mounted) return const WarmupGateResult.stop();
    }
    if (!settings.current.isOn) return const WarmupGateResult.go();

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
  if (start is WarmupGateResult) return start;
  return start == true
      ? const WarmupGateResult.go()
      : const WarmupGateResult.stop();
}

/// Plan trwającej rozgrzewki: najpierw z listy widoku, a gdy jej tam nie ma
/// (lista może się jeszcze ładować), z repozytorium. `null` znaczy, że planu
/// na pewno nie ma; błąd odczytu leci wyżej, żeby nie kasować rozgrzewki.
Future<CustomTrainingPlan?> findWarmupPlan(
  String? planId,
  List<CustomTrainingPlan> plans,
  TrainingPlanRepository repository,
) async {
  if (planId == null) return null;
  for (final plan in plans) {
    if (plan.id == planId) return plan;
  }
  return repository.getById(planId);
}
