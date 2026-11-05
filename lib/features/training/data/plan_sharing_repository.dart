import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/custom_training_plan.dart';
import 'sync/training_plan_sync_engine.dart';
import 'training_plan_remote_data_source.dart';

/// Wynik kopiowania: plan zapisany już lokalnie i liczba ćwiczeń, których
/// nie dało się skopiować (własne ćwiczenia autora).
typedef PlanCopyOutcome = ({CustomTrainingPlan plan, int skippedExercises});

/// Publiczne plany innych osób i kopiowanie ich do własnych planów. Wymaga
/// sieci — kopia powstaje na serwerze i od razu trafia do lokalnej bazy.
class PlanSharingRepository {
  PlanSharingRepository({
    required TrainingPlanRemoteDataSource remote,
    required TrainingPlanSyncEngine syncEngine,
  }) : _remote = remote,
       _sync = syncEngine;

  final TrainingPlanRemoteDataSource _remote;
  final TrainingPlanSyncEngine _sync;

  static const _uuid = Uuid();

  /// Lokalny id ostatnio skopiowanego planu — lista planów oznacza go
  /// etykietą „Nowy”, dopóki aplikacja działa.
  final recentlyCopiedPlanId = ValueNotifier<String?>(null);

  /// Kopia, o której lista planów ma jeszcze powiedzieć „Plan dodany”.
  final copyNotice = ValueNotifier<PlanCopyOutcome?>(null);

  Future<List<CustomTrainingPlan>> publicPlans(String userId) =>
      _remote.listPublic(userId);

  Future<PlanCopyOutcome> copyPlan(String planServerId) {
    return _copy((clientId) => _remote.copy(planServerId, clientId: clientId));
  }

  Future<PlanCopyOutcome> copyFromPost(String sessionId) {
    return _copy(
      (clientId) => _remote.copyFromPost(sessionId, clientId: clientId),
    );
  }

  Future<PlanCopyOutcome> _copy(
    Future<PlanCopyResult> Function(String clientId) request,
  ) async {
    final localId = _uuid.v4();
    final result = await request(localId);
    await _sync.storeCopiedPlan(result.plan, localId: localId);
    final outcome = (
      plan: result.plan.copyWith(id: localId),
      skippedExercises: result.skippedExercises,
    );
    recentlyCopiedPlanId.value = localId;
    copyNotice.value = outcome;
    return outcome;
  }
}
