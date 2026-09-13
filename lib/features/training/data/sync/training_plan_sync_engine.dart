import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/sync/sync_engine_base.dart';
import '../../../../core/sync/sync_failure.dart';
import '../../../library/data/exercise_database.dart';
import '../../../library/data/exercise_dto.dart';
import '../../../library/domain/models/exercise.dart';
import '../../domain/models/custom_training_plan.dart';
import '../training_plan_local_mapper.dart';
import '../training_plan_remote_data_source.dart';

class TrainingPlanSyncEngine extends SyncEngineBase {
  TrainingPlanSyncEngine({
    required TrainingPlanRemoteDataSource remote,
    required ExerciseDatabase localDb,
    super.onDataChanged,
  }) : _remote = remote,
       _localDb = localDb;

  final TrainingPlanRemoteDataSource _remote;
  final ExerciseDatabase _localDb;

  static const _uuid = Uuid();

  void scheduleBootstrap() {
    unawaited(
      _bootstrap().catchError((_) {
        /* bootstrap sync is best-effort */
      }),
    );
  }

  Future<void> _bootstrap() async {
    try {
      await flush();
      await pull();
    } catch (_) {
      /* offline */
    }
  }

  Future<void> flush() => runCoalesced('flush', _flushImpl);

  Future<void> pull() => runCoalesced('pull', _pullImpl);

  /// Pobiera plany z serwera, gdy ostatnia próba była dawniej niż [maxAge].
  Future<void> pullIfDue({
    Duration maxAge = SyncEngineBase.defaultPullMaxAge,
  }) {
    return runCoalesced('pull-if-due', () async {
      if (isPullDue(maxAge)) await _pullImpl();
    });
  }

  Future<void> _handleFailure(
    String localId,
    String op,
    ApiException error,
  ) async {
    await _localDb.recordSyncAttemptFailure(
      localId: localId,
      op: op,
      message: error.message,
    );
    if (registerFailure(error) == SyncFailureKind.permanent) {
      await _localDb.markSyncRejected(
        table: ExerciseDatabase.tableTrainingPlans,
        localId: localId,
        reason: error.message,
      );
    }
  }

  Future<Map<String, String>?> _serverExerciseMap(
    Database db,
    CustomTrainingPlan plan,
  ) async {
    final maybe = await TrainingPlanLocalMapper.exerciseServerIdsByLocalId(
      db,
      plan,
    );
    if (maybe.values.any((id) => id == null || id.isEmpty)) {
      return null;
    }
    return maybe.map((key, value) => MapEntry(key, value!));
  }

  // ── Flush ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>?> _pendingRows() async {
    try {
      return await _localDb.run(
        (db) => db.query(
          ExerciseDatabase.tableTrainingPlans,
          columns: ['local_id', 'server_id', 'pending_op'],
          where: 'pending_op IS NOT NULL AND sync_error IS NULL',
          orderBy:
              "CASE pending_op WHEN 'create' THEN 0 WHEN 'update' THEN 1 ELSE 2 END",
        ),
      );
    } on StateError {
      return null; /* DB closing */
    }
  }

  Future<void> _flushImpl() async {
    if (isStopped) return;
    final rows = await _pendingRows();
    if (rows == null || rows.isEmpty) return;

    final networkMark = networkFailureMark;
    var changed = false;
    for (final row in rows) {
      if (isStopped) return;
      final localId = row['local_id'] as String;
      try {
        final synced = row['pending_op'] == 'delete'
            ? await _flushDelete(localId, row['server_id'] as String?)
            : await _flushUpsert(localId);
        if (synced) changed = true;
      } catch (error, stackTrace) {
        if (isStopped) return;
        // Jeden uszkodzony wiersz nie może zablokować wysyłki pozostałych.
        logUnexpected('Training plan $localId sync failed', error, stackTrace);
      }
      if (networkFailedSince(networkMark)) break;
    }
    if (changed) notifyDataChanged();
  }

  Future<bool> _flushDelete(String localId, String? serverId) async {
    if (serverId != null) {
      try {
        await _remote.delete(serverId);
      } on ApiException catch (e) {
        // 404 — planu już nie ma na serwerze, cel usunięcia osiągnięty.
        if (e.statusCode != 404) {
          await _handleFailure(localId, 'delete_plan', e);
          return false;
        }
      }
    }
    await _localDb.run(
      (db) => db.delete(
        ExerciseDatabase.tableTrainingPlans,
        where: 'local_id = ?',
        whereArgs: [localId],
      ),
    );
    await _localDb.clearSyncAttempts(localId);
    return true;
  }

  Future<bool> _flushUpsert(String localId) async {
    // Świeży odczyt — wiersz mógł się zmienić od zapytania o kolejkę.
    final payload = await _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingPlans,
        where: 'local_id = ?',
        whereArgs: [localId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      final op = row['pending_op'] as String?;
      if (op != 'create' && op != 'update') return null;
      final record = await TrainingPlanLocalMapper.fromDb(db, row);
      if (record == null) return null;
      // Ćwiczenie dodane offline nie ma jeszcze server_id — plan poczeka.
      final exerciseMap = await _serverExerciseMap(db, record.plan);
      if (exerciseMap == null) return null;
      return _PlanPayload(
        op: op!,
        serverId: row['server_id'] as String?,
        updatedAt: row['updated_at'] as int?,
        plan: record.plan,
        exerciseServerIds: exerciseMap,
      );
    });
    if (payload == null) return false;

    final saved = await _send(localId, payload);
    if (saved == null) return false;

    await _storePulledPlan(
      saved,
      localIdOverride: localId,
      expectedUpdatedAt: payload.updatedAt,
      sentOp: payload.op,
    );
    await _localDb.clearSyncAttempts(localId);
    return true;
  }

  Future<CustomTrainingPlan?> _send(String localId, _PlanPayload payload) async {
    final serverId = payload.serverId;
    try {
      // server_id == local_id to ślad starego błędu — create po clientId go naprawia.
      if (payload.op == 'create' || serverId == null || serverId == localId) {
        return await _remote.create(
          payload.plan,
          exerciseServerIdsByLocalId: payload.exerciseServerIds,
        );
      }
      return await _remote.update(
        serverId,
        payload.plan,
        exerciseServerIdsByLocalId: payload.exerciseServerIds,
      );
    } on ApiException catch (e) {
      await _handleFailure(localId, '${payload.op}_plan', e);
      return null;
    }
  }

  // ── Pull ──────────────────────────────────────────────────────────────────

  Future<void> _pullImpl() async {
    if (isStopped) return;
    markPullAttempt();
    try {
      final serverPlans = await _remote.getAll();
      if (isStopped) return;
      await _localDb.run((db) async {
        await db.transaction((txn) async {
          for (final plan in serverPlans) {
            await _storePulledPlanOn(txn, plan);
          }
          final serverIds = serverPlans.map((p) => p.id).toSet();
          final rows = await txn.query(
            ExerciseDatabase.tableTrainingPlans,
            columns: ['local_id', 'server_id', 'pending_op'],
          );
          final orphanIds = <String>[
            for (final row in rows)
              if (row['pending_op'] == null &&
                  row['server_id'] != null &&
                  !serverIds.contains(row['server_id']))
                row['local_id'] as String,
          ];
          const chunkSize = 900;
          for (var i = 0; i < orphanIds.length; i += chunkSize) {
            final end = i + chunkSize > orphanIds.length
                ? orphanIds.length
                : i + chunkSize;
            final chunk = orphanIds.sublist(i, end);
            final placeholders = List.filled(chunk.length, '?').join(', ');
            await txn.delete(
              ExerciseDatabase.tableTrainingPlans,
              where: 'local_id IN ($placeholders)',
              whereArgs: chunk,
            );
          }
        });
      });
      notifyDataChanged();
    } on ApiException catch (e) {
      registerFailure(e);
    } on StateError {
      /* DB closing */
    }
  }

  Future<String> _ensureExerciseLocalRow(
    DatabaseExecutor db,
    Exercise exercise,
  ) async {
    var existing = await db.query(
      ExerciseDatabase.tableExercises,
      where: 'server_id = ? OR local_id = ?',
      whereArgs: [exercise.id, exercise.id],
      limit: 1,
    );
    final clientId = exercise.clientId;
    if (existing.isEmpty && clientId != null) {
      existing = await db.query(
        ExerciseDatabase.tableExercises,
        where: 'local_id = ?',
        whereArgs: [clientId],
        limit: 1,
      );
    }
    if (existing.isNotEmpty) return existing.first['local_id'] as String;
    final localId = _uuid.v4();
    await db.insert(
      ExerciseDatabase.tableExercises,
      ExerciseDto.fromPulledServer(exercise, localId).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return localId;
  }

  Future<Map<String, dynamic>?> _findLocalRow(
    DatabaseExecutor db,
    CustomTrainingPlan plan, {
    String? localIdOverride,
  }) async {
    if (localIdOverride != null) {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingPlans,
        where: 'local_id = ?',
        whereArgs: [localIdOverride],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first;
    }
    var rows = await db.query(
      ExerciseDatabase.tableTrainingPlans,
      where: 'server_id = ?',
      whereArgs: [plan.id],
      limit: 1,
    );
    final clientId = plan.clientId;
    if (rows.isEmpty && clientId != null) {
      // Plan utworzony offline na tym urządzeniu, którego odpowiedź na POST
      // mogła się zgubić — bez tego pull wstawiłby jego duplikat.
      rows = await db.query(
        ExerciseDatabase.tableTrainingPlans,
        where: 'local_id = ?',
        whereArgs: [clientId],
        limit: 1,
      );
    }
    return rows.isEmpty ? null : rows.first;
  }

  /// Usuwa inne wiersze wskazujące ten sam plan na serwerze (duplikaty ze
  /// starszych wersji synchronizacji) i przepina na [keepLocalId] sesje.
  Future<void> _removeDuplicateServerRows(
    DatabaseExecutor db, {
    required String serverId,
    required String keepLocalId,
  }) async {
    final duplicates = await db.query(
      ExerciseDatabase.tableTrainingPlans,
      columns: ['local_id'],
      where: 'server_id = ? AND local_id <> ?',
      whereArgs: [serverId, keepLocalId],
    );
    for (final duplicate in duplicates) {
      await db.update(
        ExerciseDatabase.tableTrainingSessions,
        {'plan_local_id': keepLocalId},
        where: 'plan_local_id = ?',
        whereArgs: [duplicate['local_id']],
      );
      await db.delete(
        ExerciseDatabase.tableTrainingPlans,
        where: 'local_id = ?',
        whereArgs: [duplicate['local_id']],
      );
    }
  }

  /// Zapisuje plan z serwera lokalnie.
  ///
  /// * Z [localIdOverride] — odpowiedź na wysyłkę tego wiersza. Jeśli wiersz
  ///   zmienił się w trakcie żądania ([expectedUpdatedAt]), zapamiętujemy
  ///   tylko `server_id`, a nowsza wersja pójdzie w kolejnym cyklu.
  /// * Bez niego — pobranie listy. Wiersz z niewysłanymi zmianami zostaje
  ///   nietknięty; wcześniej pull nadpisywał edycje zrobione offline.
  Future<void> _storePulledPlan(
    CustomTrainingPlan plan, {
    String? localIdOverride,
    int? expectedUpdatedAt,
    String? sentOp,
  }) {
    return _localDb.run(
      (db) => _storePulledPlanOn(
        db,
        plan,
        localIdOverride: localIdOverride,
        expectedUpdatedAt: expectedUpdatedAt,
        sentOp: sentOp,
      ),
    );
  }

  Future<void> _storePulledPlanOn(
    DatabaseExecutor db,
    CustomTrainingPlan plan, {
    String? localIdOverride,
    int? expectedUpdatedAt,
    String? sentOp,
  }) async {
      final existing = await _findLocalRow(
        db,
        plan,
        localIdOverride: localIdOverride,
      );
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;

      if (localIdOverride != null && existing == null) {
        // Usunięty lokalnie, zanim serwer odpowiedział — nagrobek usunie plan
        // także z serwera przy następnej wysyłce.
        await _removeDuplicateServerRows(
          db,
          serverId: plan.id,
          keepLocalId: localIdOverride,
        );
        await db.insert(ExerciseDatabase.tableTrainingPlans, {
          'local_id': localIdOverride,
          'server_id': plan.id,
          'name': plan.name,
          'note': plan.note,
          'selected_days': TrainingPlanLocalMapper.encodeDays(
            plan.selectedDays,
          ),
          'created_at': now,
          'updated_at': now,
          'pending_op': 'delete',
          'is_deleted': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        return;
      }

      if (existing != null) {
        final pending = existing['pending_op'] as String?;
        final editedLocally = localIdOverride == null
            ? pending != null
            : expectedUpdatedAt != null &&
                  existing['updated_at'] != expectedUpdatedAt;
        if (editedLocally) {
          final localId = existing['local_id'] as String;
          await _removeDuplicateServerRows(
            db,
            serverId: plan.id,
            keepLocalId: localId,
          );
          await db.update(
            ExerciseDatabase.tableTrainingPlans,
            {
              'server_id': plan.id,
              // Wysłana wersja jest już na serwerze; nowsza pójdzie jako update.
              if (sentOp == 'create' && pending == 'create')
                'pending_op': 'update',
            },
            where: 'local_id = ?',
            whereArgs: [localId],
          );
          return;
        }
      }

      final localId =
          localIdOverride ??
          (existing?['local_id'] as String?) ??
          _uuid.v4();
      await _removeDuplicateServerRows(
        db,
        serverId: plan.id,
        keepLocalId: localId,
      );
      await db.insert(
        ExerciseDatabase.tableTrainingPlans,
        {
          'local_id': localId,
          'server_id': plan.id,
          'name': plan.name,
          'note': plan.note,
          'selected_days': TrainingPlanLocalMapper.encodeDays(
            plan.selectedDays,
          ),
          'created_at': existing?['created_at'] ?? now,
          'updated_at': now,
          'pending_op': null,
          'is_deleted': 0,
          'sync_error': null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final exerciseServerIds = <String, String?>{};
      final localPlanExercises = <PlanExercise>[];
      for (final pe in plan.exercises) {
        final localExerciseId = await _ensureExerciseLocalRow(db, pe.exercise);
        exerciseServerIds[localExerciseId] = pe.exercise.id;
        localPlanExercises.add(
          pe.copyWith(
            exercise: Exercise(
              id: localExerciseId,
              name: pe.exercise.name,
              muscles: pe.exercise.muscles,
              category: pe.exercise.category,
              description: pe.exercise.description,
              imageUrl: pe.exercise.imageUrl,
              isMine: pe.exercise.isMine,
              createdAt: pe.exercise.createdAt,
            ),
          ),
        );
      }

      await TrainingPlanLocalMapper.replacePlanChildren(
        db,
        CustomTrainingPlan(
          id: localId,
          name: plan.name,
          note: plan.note,
          selectedDays: plan.selectedDays,
          exercises: localPlanExercises,
        ),
        exerciseServerIdsByLocalId: exerciseServerIds,
      );
  }
}

class _PlanPayload {
  const _PlanPayload({
    required this.op,
    required this.serverId,
    required this.updatedAt,
    required this.plan,
    required this.exerciseServerIds,
  });

  final String op;
  final String? serverId;
  final int? updatedAt;
  final CustomTrainingPlan plan;
  final Map<String, String> exerciseServerIds;
}
