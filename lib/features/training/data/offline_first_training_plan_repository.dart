import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../library/data/exercise_database.dart';
import '../domain/models/custom_training_plan.dart';
import '../domain/repositories/training_plan_repository.dart';
import 'sync/training_plan_sync_engine.dart';
import 'training_plan_local_mapper.dart';

class OfflineFirstTrainingPlanRepository implements TrainingPlanRepository {
  OfflineFirstTrainingPlanRepository({
    required ExerciseDatabase localDb,
    required TrainingPlanSyncEngine syncEngine,
  })  : _localDb = localDb,
        _sync = syncEngine;

  final ExerciseDatabase _localDb;
  final TrainingPlanSyncEngine _sync;

  static const _uuid = Uuid();

  void _scheduleSync() {
    if (_sync.isStopped) return;
    unawaited(
      _sync.flush().then((_) => _sync.pull()).catchError((_) {
        /* background sync must never break the UI event loop */
      }),
    );
  }

  Future<Map<String, dynamic>?> _findRow(Database db, String id) async {
    final byLocal = await db.query(
      ExerciseDatabase.tableTrainingPlans,
      where: 'local_id = ?',
      whereArgs: [id],
    );
    if (byLocal.isNotEmpty) return byLocal.first;
    final byServer = await db.query(
      ExerciseDatabase.tableTrainingPlans,
      where: 'server_id = ?',
      whereArgs: [id],
    );
    if (byServer.isNotEmpty) return byServer.first;
    return null;
  }

  @override
  Future<List<CustomTrainingPlan>> getAll() async {
    final plans = await _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingPlans,
        where: 'is_deleted = 0',
        orderBy: 'updated_at DESC',
      );
      final records = <CustomTrainingPlan>[];
      for (final row in rows) {
        final record = await TrainingPlanLocalMapper.fromDb(db, row);
        if (record != null && !record.isDeleted) records.add(record.plan);
      }
      return records;
    });
    _scheduleSync();
    return plans;
  }

  @override
  Future<CustomTrainingPlan?> getById(String id) async {
    return _localDb.run((db) async {
      final row = await _findRow(db, id);
      if (row == null) return null;
      final record = await TrainingPlanLocalMapper.fromDb(db, row);
      if (record == null || record.isDeleted) return null;
      return record.plan;
    });
  }

  @override
  Future<CustomTrainingPlan> create(CustomTrainingPlan plan) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final localPlan = plan.id.isEmpty
        ? plan.copyWith(id: _uuid.v4())
        : plan;
    await _localDb.run((db) async {
      final exerciseServerIds =
          await TrainingPlanLocalMapper.exerciseServerIdsByLocalId(
        db,
        localPlan,
      );
      await db.insert(
        ExerciseDatabase.tableTrainingPlans,
        {
          'local_id': localPlan.id,
          'server_id': null,
          'name': localPlan.name,
          'note': localPlan.note,
          'selected_days':
              TrainingPlanLocalMapper.encodeDays(localPlan.selectedDays),
          'created_at': now,
          'updated_at': now,
          'pending_op': 'create',
          'is_deleted': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await TrainingPlanLocalMapper.replacePlanChildren(
        db,
        localPlan,
        exerciseServerIdsByLocalId: exerciseServerIds,
      );
    });
    _scheduleSync();
    return localPlan;
  }

  @override
  Future<CustomTrainingPlan> update(CustomTrainingPlan plan) async {
    String resolvedLocalId = plan.id;
    await _localDb.run((db) async {
      final row = await _findRow(db, plan.id);
      if (row == null) return;
      final localId = row['local_id'] as String;
      resolvedLocalId = localId;
      final pending = row['pending_op'] as String?;
      final nextPending = pending == 'create' ? 'create' : 'update';
      final exerciseServerIds =
          await TrainingPlanLocalMapper.exerciseServerIdsByLocalId(db, plan);
      await db.update(
        ExerciseDatabase.tableTrainingPlans,
        {
          'name': plan.name,
          'note': plan.note,
          'selected_days': TrainingPlanLocalMapper.encodeDays(plan.selectedDays),
          'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
          'pending_op': nextPending,
          'is_deleted': 0,
        },
        where: 'local_id = ?',
        whereArgs: [localId],
      );
      await TrainingPlanLocalMapper.replacePlanChildren(
        db,
        plan.copyWith(id: localId),
        exerciseServerIdsByLocalId: exerciseServerIds,
      );
    });
    _scheduleSync();
    return plan.copyWith(id: resolvedLocalId);
  }

  @override
  Future<void> delete(String id) async {
    await _localDb.run((db) async {
      final row = await _findRow(db, id);
      if (row == null) return;
      final localId = row['local_id'] as String;
      final pending = row['pending_op'] as String?;
      if (pending == 'create') {
        final oldExercises = await db.query(
          ExerciseDatabase.tableTrainingPlanExercises,
          columns: ['local_id'],
          where: 'plan_local_id = ?',
          whereArgs: [localId],
        );
        for (final old in oldExercises) {
          await db.delete(
            ExerciseDatabase.tableTrainingPlanSets,
            where: 'plan_exercise_local_id = ?',
            whereArgs: [old['local_id']],
          );
        }
        await db.delete(
          ExerciseDatabase.tableTrainingPlanExercises,
          where: 'plan_local_id = ?',
          whereArgs: [localId],
        );
        await db.delete(
          ExerciseDatabase.tableTrainingPlans,
          where: 'local_id = ?',
          whereArgs: [localId],
        );
        await db.insert(ExerciseDatabase.tableOutboxLog, {
          'local_id': localId,
          'op': 'skipped_pending_plan_create',
          'attempts': 0,
          'last_error': null,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
        return;
      }
      await db.update(
        ExerciseDatabase.tableTrainingPlans,
        {
          'pending_op': 'delete',
          'is_deleted': 1,
          'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        },
        where: 'local_id = ?',
        whereArgs: [localId],
      );
    });
    _scheduleSync();
  }
}
