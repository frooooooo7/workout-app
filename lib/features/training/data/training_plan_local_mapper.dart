import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../library/data/exercise_database.dart';
import '../../library/data/exercise_dto.dart';
import '../../library/domain/models/exercise.dart';
import '../domain/models/custom_training_plan.dart';

class LocalTrainingPlanRecord {
  const LocalTrainingPlanRecord({
    required this.plan,
    this.serverId,
    this.pendingOp,
    required this.isDeleted,
  });

  final CustomTrainingPlan plan;
  final String? serverId;
  final String? pendingOp;
  final bool isDeleted;
}

class TrainingPlanLocalMapper {
  static const _uuid = Uuid();

  static String encodeDays(List<int> days) => jsonEncode(days);

  static List<int> decodeDays(String raw) =>
      (jsonDecode(raw) as List).map((d) => d as int).toList();

  static Future<Exercise?> _exerciseForPlanRow(
    Database db,
    Map<String, dynamic> planExercise,
  ) async {
    final localId = planExercise['exercise_local_id'] as String;
    final serverId = planExercise['exercise_server_id'] as String?;
    var rows = await db.query(
      ExerciseDatabase.tableExercises,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
    if (rows.isEmpty && serverId != null) {
      rows = await db.query(
        ExerciseDatabase.tableExercises,
        where: 'server_id = ?',
        whereArgs: [serverId],
      );
    }
    if (rows.isEmpty) return null;
    return ExerciseDto.fromMap(rows.first).toDomain();
  }

  static Future<LocalTrainingPlanRecord?> fromDb(
    Database db,
    Map<String, dynamic> planRow,
  ) async {
    final planExerciseRows = await db.query(
      ExerciseDatabase.tableTrainingPlanExercises,
      where: 'plan_local_id = ?',
      whereArgs: [planRow['local_id']],
      orderBy: 'position ASC',
    );

    final planExercises = <PlanExercise>[];
    for (final planExerciseRow in planExerciseRows) {
      final exercise = await _exerciseForPlanRow(db, planExerciseRow);
      if (exercise == null) continue;
      final setRows = await db.query(
        ExerciseDatabase.tableTrainingPlanSets,
        where: 'plan_exercise_local_id = ?',
        whereArgs: [planExerciseRow['local_id']],
        orderBy: 'position ASC',
      );
      planExercises.add(
        PlanExercise(
          id: planExerciseRow['local_id'] as String,
          exercise: exercise,
          sets: setRows
              .map((set) => ExerciseSet(
                    id: set['local_id'] as String,
                    weight: set['weight'] as String?,
                    reps: set['reps'] as String? ?? '',
                    rir: set['rir'] as String?,
                    tempo: set['tempo'] as String?,
                  ))
              .toList(),
        ),
      );
    }

    return LocalTrainingPlanRecord(
      plan: CustomTrainingPlan(
        id: planRow['local_id'] as String,
        name: planRow['name'] as String,
        note: planRow['note'] as String?,
        selectedDays: decodeDays(planRow['selected_days'] as String),
        exercises: planExercises,
      ),
      serverId: planRow['server_id'] as String?,
      pendingOp: planRow['pending_op'] as String?,
      isDeleted: ((planRow['is_deleted'] as int?) ?? 0) == 1,
    );
  }

  static Future<void> replacePlanChildren(
    Database db,
    CustomTrainingPlan plan, {
    required Map<String, String?> exerciseServerIdsByLocalId,
    Map<String, String>? planExerciseServerIdsByLocalId,
    Map<String, String>? setServerIdsByLocalId,
  }) async {
    final oldExercises = await db.query(
      ExerciseDatabase.tableTrainingPlanExercises,
      columns: ['local_id'],
      where: 'plan_local_id = ?',
      whereArgs: [plan.id],
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
      whereArgs: [plan.id],
    );

    final usedPlanExerciseIds = <String>{};
    final usedSetIds = <String>{};
    for (final entry in plan.exercises.asMap().entries) {
      final pe = entry.value;
      final planExerciseId = await _availableLocalId(
        db,
        ExerciseDatabase.tableTrainingPlanExercises,
        pe.id,
        usedPlanExerciseIds,
        ownerColumn: 'plan_local_id',
        ownerId: plan.id,
      );
      usedPlanExerciseIds.add(planExerciseId);
      await db.insert(ExerciseDatabase.tableTrainingPlanExercises, {
        'local_id': planExerciseId,
        'server_id': planExerciseServerIdsByLocalId?[pe.id],
        'plan_local_id': plan.id,
        'exercise_local_id': pe.exercise.id,
        'exercise_server_id': exerciseServerIdsByLocalId[pe.exercise.id],
        'position': entry.key,
      });
      for (final setEntry in pe.sets.asMap().entries) {
        final set = setEntry.value;
        final setId = await _availableLocalId(
          db,
          ExerciseDatabase.tableTrainingPlanSets,
          set.id,
          usedSetIds,
          ownerColumn: 'plan_exercise_local_id',
          ownerId: planExerciseId,
        );
        usedSetIds.add(setId);
        await db.insert(ExerciseDatabase.tableTrainingPlanSets, {
          'local_id': setId,
          'server_id': setServerIdsByLocalId?[set.id],
          'plan_exercise_local_id': planExerciseId,
          'position': setEntry.key,
          'weight': set.weight,
          'reps': set.reps,
          'rir': set.rir,
          'tempo': set.tempo,
        });
      }
    }
  }

  static Future<String> _availableLocalId(
    Database db,
    String table,
    String preferredId,
    Set<String> usedIds, {
    required String ownerColumn,
    required String ownerId,
  }) async {
    if (usedIds.contains(preferredId)) {
      return _uuid.v4();
    }
    final rows = await db.query(
      table,
      columns: [ownerColumn],
      where: 'local_id = ?',
      whereArgs: [preferredId],
      limit: 1,
    );
    if (rows.isEmpty || rows.first[ownerColumn] == ownerId) {
      return preferredId;
    }
    return _uuid.v4();
  }

  static Future<Map<String, String?>> exerciseServerIdsByLocalId(
    Database db,
    CustomTrainingPlan plan,
  ) async {
    final result = <String, String?>{};
    for (final pe in plan.exercises) {
      final rows = await db.query(
        ExerciseDatabase.tableExercises,
        columns: ['local_id', 'server_id'],
        where: 'local_id = ? OR server_id = ?',
        whereArgs: [pe.exercise.id, pe.exercise.id],
      );
      if (rows.isEmpty) {
        result[pe.exercise.id] = null;
      } else {
        result[pe.exercise.id] = rows.first['server_id'] as String?;
      }
    }
    return result;
  }
}
