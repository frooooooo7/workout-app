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
  static const _inChunkSize = 900;
  // `local_id IN (...) OR server_id IN (...)` — dwa razy tyle placeholderów.
  static const _dualInChunkSize = 450;

  static String encodeDays(List<int> days) => jsonEncode(days);

  static List<int> decodeDays(String raw) =>
      (jsonDecode(raw) as List).map((d) => d as int).toList();

  static Future<LocalTrainingPlanRecord?> fromDb(
    DatabaseExecutor db,
    Map<String, dynamic> planRow,
  ) async {
    final mapped = await fromDbMany(db, [planRow]);
    return mapped.isEmpty ? null : mapped.first;
  }

  /// Ładuje dzieci planów (ćwiczenia, serie, wiersze biblioteki) zapytaniami
  /// `IN` — bez pętli `query` na każde ćwiczenie.
  static Future<List<LocalTrainingPlanRecord>> fromDbMany(
    DatabaseExecutor db,
    List<Map<String, dynamic>> planRows,
  ) async {
    if (planRows.isEmpty) return const [];

    final planIds = [for (final row in planRows) row['local_id'] as String];
    final planExerciseRows = await _queryIn(
      db,
      ExerciseDatabase.tableTrainingPlanExercises,
      column: 'plan_local_id',
      ids: planIds,
      orderBy: 'position ASC',
    );

    final planExerciseIds = [
      for (final row in planExerciseRows) row['local_id'] as String,
    ];
    final setRows = await _queryIn(
      db,
      ExerciseDatabase.tableTrainingPlanSets,
      column: 'plan_exercise_local_id',
      ids: planExerciseIds,
      orderBy: 'position ASC',
    );

    final exerciseLookupIds = <String>{};
    for (final row in planExerciseRows) {
      exerciseLookupIds.add(row['exercise_local_id'] as String);
      final serverId = row['exercise_server_id'] as String?;
      if (serverId != null && serverId.isNotEmpty) {
        exerciseLookupIds.add(serverId);
      }
    }
    final exerciseRows = await _queryByLocalOrServerId(
      db,
      ExerciseDatabase.tableExercises,
      ids: exerciseLookupIds.toList(),
    );

    final exerciseByLocalId = <String, Exercise>{};
    final exerciseByServerId = <String, Exercise>{};
    for (final row in exerciseRows) {
      final exercise = ExerciseDto.fromMap(row).toDomain();
      exerciseByLocalId[row['local_id'] as String] = exercise;
      final serverId = row['server_id'] as String?;
      if (serverId != null && serverId.isNotEmpty) {
        exerciseByServerId[serverId] = exercise;
      }
    }

    final planExercisesByPlan = <String, List<Map<String, dynamic>>>{};
    for (final row in planExerciseRows) {
      final planId = row['plan_local_id'] as String;
      (planExercisesByPlan[planId] ??= []).add(row);
    }
    final setsByPlanExercise = <String, List<Map<String, dynamic>>>{};
    for (final row in setRows) {
      final planExerciseId = row['plan_exercise_local_id'] as String;
      (setsByPlanExercise[planExerciseId] ??= []).add(row);
    }

    return [
      for (final planRow in planRows)
        _recordFromGrouped(
          planRow: planRow,
          planExerciseRows:
              planExercisesByPlan[planRow['local_id'] as String] ?? const [],
          setsByPlanExercise: setsByPlanExercise,
          exerciseByLocalId: exerciseByLocalId,
          exerciseByServerId: exerciseByServerId,
        ),
    ];
  }

  static LocalTrainingPlanRecord _recordFromGrouped({
    required Map<String, dynamic> planRow,
    required List<Map<String, dynamic>> planExerciseRows,
    required Map<String, List<Map<String, dynamic>>> setsByPlanExercise,
    required Map<String, Exercise> exerciseByLocalId,
    required Map<String, Exercise> exerciseByServerId,
  }) {
    final planExercises = <PlanExercise>[];
    for (final planExerciseRow in planExerciseRows) {
      final localId = planExerciseRow['exercise_local_id'] as String;
      final serverId = planExerciseRow['exercise_server_id'] as String?;
      final exercise =
          exerciseByLocalId[localId] ??
          (serverId != null ? exerciseByServerId[serverId] : null);
      if (exercise == null) continue;
      final setRows =
          setsByPlanExercise[planExerciseRow['local_id'] as String] ??
          const <Map<String, dynamic>>[];
      planExercises.add(
        PlanExercise(
          id: planExerciseRow['local_id'] as String,
          exercise: exercise,
          sets: [
            for (final set in setRows)
              ExerciseSet(
                id: set['local_id'] as String,
                weight: set['weight'] as String?,
                reps: set['reps'] as String? ?? '',
                rir: set['rir'] as String?,
                tempo: set['tempo'] as String?,
              ),
          ],
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
    DatabaseExecutor db,
    CustomTrainingPlan plan, {
    required Map<String, String?> exerciseServerIdsByLocalId,
    Map<String, String>? planExerciseServerIdsByLocalId,
    Map<String, String>? setServerIdsByLocalId,
  }) {
    return _inTransaction(
      db,
      (txn) => _replacePlanChildrenIn(
        txn,
        plan,
        exerciseServerIdsByLocalId: exerciseServerIdsByLocalId,
        planExerciseServerIdsByLocalId: planExerciseServerIdsByLocalId,
        setServerIdsByLocalId: setServerIdsByLocalId,
      ),
    );
  }

  static Future<void> _replacePlanChildrenIn(
    DatabaseExecutor db,
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
    await _deleteIn(
      db,
      ExerciseDatabase.tableTrainingPlanSets,
      column: 'plan_exercise_local_id',
      ids: [
        for (final old in oldExercises) old['local_id'] as String,
      ],
    );
    await db.delete(
      ExerciseDatabase.tableTrainingPlanExercises,
      where: 'plan_local_id = ?',
      whereArgs: [plan.id],
    );

    // Po skasowaniu dzieci tego planu pozostałe `local_id` należą do innych
    // planów. Sprawdzamy tylko identyfikatory, które chcemy wstawić — bez
    // czytania całych tabel przy każdym zapisie (i każdym planie w pull).
    final takenPlanExerciseIds = {
      for (final row in await _queryIn(
        db,
        ExerciseDatabase.tableTrainingPlanExercises,
        column: 'local_id',
        ids: [for (final pe in plan.exercises) pe.id],
        columns: ['local_id'],
      ))
        row['local_id'] as String,
    };
    final takenSetIds = {
      for (final row in await _queryIn(
        db,
        ExerciseDatabase.tableTrainingPlanSets,
        column: 'local_id',
        ids: [
          for (final pe in plan.exercises)
            for (final set in pe.sets) set.id,
        ],
        columns: ['local_id'],
      ))
        row['local_id'] as String,
    };

    final batch = db.batch();
    for (final entry in plan.exercises.asMap().entries) {
      final pe = entry.value;
      final planExerciseId = _pickLocalId(pe.id, takenPlanExerciseIds);
      takenPlanExerciseIds.add(planExerciseId);
      batch.insert(ExerciseDatabase.tableTrainingPlanExercises, {
        'local_id': planExerciseId,
        'server_id': planExerciseServerIdsByLocalId?[pe.id],
        'plan_local_id': plan.id,
        'exercise_local_id': pe.exercise.id,
        'exercise_server_id': exerciseServerIdsByLocalId[pe.exercise.id],
        'position': entry.key,
      });
      for (final setEntry in pe.sets.asMap().entries) {
        final set = setEntry.value;
        final setId = _pickLocalId(set.id, takenSetIds);
        takenSetIds.add(setId);
        batch.insert(ExerciseDatabase.tableTrainingPlanSets, {
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
    await batch.commit(noResult: true);
  }

  static String _pickLocalId(String preferredId, Set<String> usedIds) {
    if (usedIds.contains(preferredId)) return _uuid.v4();
    return preferredId;
  }

  static Future<Map<String, String?>> exerciseServerIdsByLocalId(
    DatabaseExecutor db,
    CustomTrainingPlan plan,
  ) async {
    final ids = {for (final pe in plan.exercises) pe.exercise.id}.toList();
    final result = <String, String?>{for (final id in ids) id: null};
    if (ids.isEmpty) return result;

    final rows = await _queryByLocalOrServerId(
      db,
      ExerciseDatabase.tableExercises,
      ids: ids,
      columns: ['local_id', 'server_id'],
    );
    final serverByKnownId = <String, String?>{};
    for (final row in rows) {
      final localId = row['local_id'] as String;
      final serverId = row['server_id'] as String?;
      serverByKnownId[localId] = serverId;
      if (serverId != null) serverByKnownId[serverId] = serverId;
    }
    for (final id in ids) {
      result[id] = serverByKnownId[id];
    }
    return result;
  }

  static Future<T> _inTransaction<T>(
    DatabaseExecutor db,
    Future<T> Function(DatabaseExecutor txn) action,
  ) {
    if (db is Transaction) return action(db);
    if (db is Database) return db.transaction(action);
    return action(db);
  }

  static Future<List<Map<String, dynamic>>> _queryIn(
    DatabaseExecutor db,
    String table, {
    required String column,
    required List<Object?> ids,
    String? orderBy,
    List<String>? columns,
  }) async {
    if (ids.isEmpty) return const [];
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < ids.length; i += _inChunkSize) {
      final end = i + _inChunkSize > ids.length ? ids.length : i + _inChunkSize;
      final chunk = ids.sublist(i, end);
      final placeholders = List.filled(chunk.length, '?').join(', ');
      out.addAll(
        await db.query(
          table,
          columns: columns,
          where: '$column IN ($placeholders)',
          whereArgs: chunk,
          orderBy: orderBy,
        ),
      );
    }
    return out;
  }

  static Future<List<Map<String, dynamic>>> _queryByLocalOrServerId(
    DatabaseExecutor db,
    String table, {
    required List<Object?> ids,
    List<String>? columns,
  }) async {
    if (ids.isEmpty) return const [];
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < ids.length; i += _dualInChunkSize) {
      final end = i + _dualInChunkSize > ids.length
          ? ids.length
          : i + _dualInChunkSize;
      final chunk = ids.sublist(i, end);
      final placeholders = List.filled(chunk.length, '?').join(', ');
      out.addAll(
        await db.query(
          table,
          columns: columns,
          where: 'local_id IN ($placeholders) OR server_id IN ($placeholders)',
          whereArgs: [...chunk, ...chunk],
        ),
      );
    }
    return out;
  }

  static Future<void> _deleteIn(
    DatabaseExecutor db,
    String table, {
    required String column,
    required List<Object?> ids,
  }) async {
    if (ids.isEmpty) return;
    for (var i = 0; i < ids.length; i += _inChunkSize) {
      final end = i + _inChunkSize > ids.length ? ids.length : i + _inChunkSize;
      final chunk = ids.sublist(i, end);
      final placeholders = List.filled(chunk.length, '?').join(', ');
      await db.delete(
        table,
        where: '$column IN ($placeholders)',
        whereArgs: chunk,
      );
    }
  }
}
