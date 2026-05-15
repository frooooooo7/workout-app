import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../library/data/exercise_database.dart';
import '../../../library/data/exercise_dto.dart';
import '../../../library/domain/models/exercise.dart';
import '../../domain/models/custom_training_plan.dart';
import '../training_plan_local_mapper.dart';
import '../training_plan_remote_data_source.dart';

class TrainingPlanSyncEngine {
  TrainingPlanSyncEngine({
    required TrainingPlanRemoteDataSource remote,
    required ExerciseDatabase localDb,
  })  : _remote = remote,
        _localDb = localDb;

  final TrainingPlanRemoteDataSource _remote;
  final ExerciseDatabase _localDb;

  static const _uuid = Uuid();

  bool _stopped = false;
  Future<void> _queue = Future<void>.value();

  bool get isStopped => _stopped;

  void stop() => _stopped = true;

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

  Future<void> _runExclusive(Future<void> Function() body) {
    final done = Completer<void>();
    _queue = _queue.then((_) async {
      try {
        await body();
        if (!done.isCompleted) done.complete();
      } catch (e, st) {
        if (!done.isCompleted) done.completeError(e, st);
      }
    });
    return done.future;
  }

  Future<void> flush() => _runExclusive(_flushImpl);

  Future<void> pull() => _runExclusive(_pullImpl);

  Future<void> _logFailure(String localId, String op, ApiException e) async {
    await _localDb.run((db) async {
      final rows = await db.rawQuery(
        '''
        SELECT COALESCE(MAX(attempts), 0) AS m
        FROM ${ExerciseDatabase.tableOutboxLog}
        WHERE local_id = ? AND op = ?
        ''',
        [localId, op],
      );
      final next = ((rows.first['m'] as int?) ?? 0) + 1;
      await db.insert(ExerciseDatabase.tableOutboxLog, {
        'local_id': localId,
        'op': op,
        'attempts': next,
        'last_error': e.message,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  Future<LocalTrainingPlanRecord?> _recordForRow(
    Database db,
    Map<String, dynamic> row,
  ) =>
      TrainingPlanLocalMapper.fromDb(db, row);

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

  Future<void> _flushImpl() async {
    if (_stopped) return;
    try {
      final rows = await _localDb.run((db) {
        return db.query(
          ExerciseDatabase.tableTrainingPlans,
          where: 'pending_op IS NOT NULL',
          orderBy:
              "CASE pending_op WHEN 'create' THEN 0 WHEN 'update' THEN 1 ELSE 2 END",
        );
      });
      for (final row in rows) {
        if (_stopped) return;
        final op = row['pending_op'] as String?;
        if (op == 'delete') {
          await _flushDelete(row);
        } else if (op == 'create' || op == 'update') {
          await _flushUpsert(row, op!);
        }
      }
    } on StateError {
      /* DB closing */
    }
  }

  Future<void> _flushDelete(Map<String, dynamic> row) async {
    final localId = row['local_id'] as String;
    final serverId = row['server_id'] as String?;
    if (serverId == null) return;
    try {
      await _remote.delete(serverId);
      await _localDb.run((db) async {
        await db.delete(
          ExerciseDatabase.tableTrainingPlans,
          where: 'local_id = ?',
          whereArgs: [localId],
        );
      });
    } on ApiException catch (e) {
      await _logFailure(localId, 'delete_plan', e);
    }
  }

  Future<void> _flushUpsert(Map<String, dynamic> row, String op) async {
    final localId = row['local_id'] as String;
    try {
      final payload = await _localDb.run((db) async {
        final record = await _recordForRow(db, row);
        if (record == null) return null;
        final exerciseMap = await _serverExerciseMap(db, record.plan);
        if (exerciseMap == null) return null;
        return (record, exerciseMap);
      });
      if (payload == null) return;
      final (record, exerciseMap) = payload;
      final serverId = row['server_id'] as String?;
      final saved = op == 'create' || serverId == null || serverId == localId
          ? await _remote.create(
              record.plan,
              exerciseServerIdsByLocalId: exerciseMap,
            )
          : await _remote.update(
              serverId,
              record.plan,
              exerciseServerIdsByLocalId: exerciseMap,
            );
      await _storePulledPlan(saved, localIdOverride: localId);
    } on ApiException catch (e) {
      await _logFailure(localId, '${op}_plan', e);
    }
  }

  Future<void> _pullImpl() async {
    if (_stopped) return;
    try {
      final serverPlans = await _remote.getAll();
      if (_stopped) return;
      for (final plan in serverPlans) {
        await _storePulledPlan(plan);
      }
      await _localDb.run((db) async {
        final serverIds = serverPlans.map((p) => p.id).toSet();
        final rows = await db.query(
          ExerciseDatabase.tableTrainingPlans,
          columns: ['local_id', 'server_id', 'pending_op'],
        );
        for (final row in rows) {
          if (row['pending_op'] != null) continue;
          final sid = row['server_id'] as String?;
          if (sid != null && !serverIds.contains(sid)) {
            await db.delete(
              ExerciseDatabase.tableTrainingPlans,
              where: 'local_id = ?',
              whereArgs: [row['local_id']],
            );
          }
        }
      });
    } on ApiException {
      /* offline */
    } on StateError {
      /* DB closing */
    }
  }

  Future<String> _ensureExerciseLocalRow(Database db, Exercise exercise) async {
    final existing = await db.query(
      ExerciseDatabase.tableExercises,
      where: 'server_id = ? OR local_id = ?',
      whereArgs: [exercise.id, exercise.id],
    );
    if (existing.isNotEmpty) return existing.first['local_id'] as String;
    final localId = _uuid.v4();
    await db.insert(
      ExerciseDatabase.tableExercises,
      ExerciseDto.fromPulledServer(exercise, localId).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return localId;
  }

  Future<void> _storePulledPlan(
    CustomTrainingPlan plan, {
    String? localIdOverride,
  }) async {
    await _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingPlans,
        where: localIdOverride != null ? 'local_id = ?' : 'server_id = ?',
        whereArgs: [localIdOverride ?? plan.id],
      );
      final localId =
          localIdOverride ?? (rows.isEmpty ? _uuid.v4() : rows.first['local_id'] as String);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await db.insert(
        ExerciseDatabase.tableTrainingPlans,
        {
          'local_id': localId,
          'server_id': plan.id,
          'name': plan.name,
          'note': plan.note,
          'selected_days': TrainingPlanLocalMapper.encodeDays(plan.selectedDays),
          'created_at': rows.isEmpty ? now : rows.first['created_at'],
          'updated_at': now,
          'pending_op': null,
          'is_deleted': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final exerciseServerIds = <String, String?>{};
      final localPlanExercises = <PlanExercise>[];
      for (final pe in plan.exercises) {
        final localExerciseId = await _ensureExerciseLocalRow(db, pe.exercise);
        exerciseServerIds[localExerciseId] = pe.exercise.id;
        localPlanExercises.add(
          pe.copyWith(exercise: Exercise(
            id: localExerciseId,
            name: pe.exercise.name,
            muscles: pe.exercise.muscles,
            category: pe.exercise.category,
            description: pe.exercise.description,
            imageUrl: pe.exercise.imageUrl,
            isMine: pe.exercise.isMine,
            createdAt: pe.exercise.createdAt,
          )),
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
    });
  }
}
