import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../library/data/exercise_database.dart';
import '../domain/models/custom_training_plan.dart';
import '../domain/models/post_draft.dart';
import '../domain/repositories/training_plan_repository.dart';
import 'pending_plan_cover_store.dart';
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

  /// Wysyła lokalne zmiany od razu, a plany z serwera pobiera najwyżej raz na
  /// [SyncEngineBase.defaultPullMaxAge]. Pull nie nadpisuje niewysłanych edycji.
  void _scheduleSync() {
    if (_sync.isStopped) return;
    unawaited(
      _sync.flush().catchError((_) {
        /* background sync must never break the UI event loop */
      }),
    );
    unawaited(
      _sync.pullIfDue().catchError((_) {
        /* background sync must never break the UI event loop */
      }),
    );
  }

  Future<Map<String, dynamic>?> _findRow(DatabaseExecutor db, String id) async {
    final rows = await db.rawQuery(
      'SELECT * FROM ${ExerciseDatabase.tableTrainingPlans} '
      'WHERE local_id = ? OR server_id = ? '
      'ORDER BY CASE WHEN local_id = ? THEN 0 ELSE 1 END LIMIT 1',
      [id, id, id],
    );
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<List<CustomTrainingPlan>> getAll() async {
    final plans = await _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingPlans,
        where: 'is_deleted = 0',
        // Przesunięte plany wg miejsca; niesortowane (NULL) — na górze.
        orderBy: 'sort_order ASC, updated_at DESC',
      );
      final records = await TrainingPlanLocalMapper.fromDbMany(db, rows);
      return [
        for (final record in records)
          if (!record.isDeleted) record.plan,
      ];
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
  Future<CustomTrainingPlan> create(
    CustomTrainingPlan plan, {
    PostPhotoChange cover = const KeepPostPhoto(),
  }) async {
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
          ...TrainingPlanLocalMapper.planSettingsValues(localPlan),
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
      await PendingPlanCoverStore.put(db, localPlan.id, cover);
    });
    _scheduleSync();
    return _withCover(localPlan, cover);
  }

  @override
  Future<CustomTrainingPlan> update(
    CustomTrainingPlan plan, {
    PostPhotoChange cover = const KeepPostPhoto(),
  }) async {
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
          ...TrainingPlanLocalMapper.planSettingsValues(plan),
          'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
          'pending_op': nextPending,
          'is_deleted': 0,
          // Nowa wersja od użytkownika — daj serwerowi kolejną szansę.
          'sync_error': null,
        },
        where: 'local_id = ?',
        whereArgs: [localId],
      );
      await TrainingPlanLocalMapper.replacePlanChildren(
        db,
        plan.copyWith(id: localId),
        exerciseServerIdsByLocalId: exerciseServerIds,
      );
      await PendingPlanCoverStore.put(db, localId, cover);
    });
    _scheduleSync();
    return _withCover(plan.copyWith(id: resolvedLocalId), cover);
  }

  /// Plan tak, jak zobaczy go lista tuż po zapisie: nowa okładka od razu
  /// z bajtów, usunięta — bez zdjęcia (kolejka dopiero ją wyśle).
  CustomTrainingPlan _withCover(
    CustomTrainingPlan plan,
    PostPhotoChange cover,
  ) {
    return switch (cover) {
      KeepPostPhoto() => plan,
      SetPostPhoto(:final photo) => plan.copyWith(coverBytes: photo.bytes),
      RemovePostPhoto() => plan.copyWith(clearCover: true),
    };
  }

  @override
  Future<void> reorder(List<String> orderedIds) async {
    await _localDb.run((db) async {
      await db.transaction((txn) async {
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        for (final entry in orderedIds.indexed) {
          final (index, id) = entry;
          final row = await _findRow(txn, id);
          if (row == null || (row['is_deleted'] as int? ?? 0) == 1) continue;
          if (row['sort_order'] == index) continue;
          final pending = row['pending_op'] as String?;
          await txn.update(
            ExerciseDatabase.tableTrainingPlans,
            {
              'sort_order': index,
              'updated_at': now,
              'pending_op': pending == 'create' ? 'create' : 'update',
              'sync_error': null,
            },
            where: 'local_id = ?',
            whereArgs: [row['local_id']],
          );
        }
      });
    });
    _scheduleSync();
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
        await PendingPlanCoverStore.remove(db, localId);
        await db.insert(ExerciseDatabase.tableOutboxLog, {
          'local_id': localId,
          'op': 'skipped_pending_plan_create',
          'attempts': 0,
          'last_error': null,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        return;
      }
      await db.update(
        ExerciseDatabase.tableTrainingPlans,
        {
          'pending_op': 'delete',
          'is_deleted': 1,
          'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
          'sync_error': null,
        },
        where: 'local_id = ?',
        whereArgs: [localId],
      );
    });
    _scheduleSync();
  }
}
