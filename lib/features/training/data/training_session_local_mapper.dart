import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../library/data/exercise_database.dart';
import '../domain/models/training_session.dart';

class TrainingSessionLocalMapper {
  static const _inChunkSize = 900;

  static String encodeStrings(List<String> values) => jsonEncode(values);

  static List<String> decodeStrings(String raw) =>
      (jsonDecode(raw) as List).map((value) => value as String).toList();

  static int? encodeDate(DateTime? value) =>
      value?.toUtc().millisecondsSinceEpoch;

  static DateTime? decodeDate(Object? value) {
    final ms = value as int?;
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  static TrainingSessionStatus decodeStatus(String value) {
    return TrainingSessionStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => TrainingSessionStatus.active,
    );
  }

  static Future<TrainingSession?> fromDb(
    DatabaseExecutor db,
    Map<String, dynamic> sessionRow,
  ) async {
    final mapped = await fromDbMany(db, [sessionRow]);
    return mapped.isEmpty ? null : mapped.first;
  }

  /// Ładuje ćwiczenia i serie wszystkich sesji dwoma zapytaniami `IN`,
  /// zamiast pytać bazę raz na każde ćwiczenie.
  static Future<List<TrainingSession>> fromDbMany(
    DatabaseExecutor db,
    List<Map<String, dynamic>> sessionRows,
  ) async {
    if (sessionRows.isEmpty) return const [];

    final sessionIds = [
      for (final row in sessionRows) row['local_id'] as String,
    ];
    final exerciseRows = await _queryIn(
      db,
      ExerciseDatabase.tableTrainingSessionExercises,
      column: 'session_local_id',
      ids: sessionIds,
      orderBy: 'position ASC',
    );

    final exerciseIds = [
      for (final row in exerciseRows) row['local_id'] as String,
    ];
    final setRows = await _queryIn(
      db,
      ExerciseDatabase.tableTrainingSessionSets,
      column: 'session_exercise_local_id',
      ids: exerciseIds,
      orderBy: 'position ASC',
    );

    final exercisesBySession = <String, List<Map<String, dynamic>>>{};
    for (final row in exerciseRows) {
      final sessionId = row['session_local_id'] as String;
      (exercisesBySession[sessionId] ??= []).add(row);
    }
    final setsByExercise = <String, List<Map<String, dynamic>>>{};
    for (final row in setRows) {
      final exerciseId = row['session_exercise_local_id'] as String;
      (setsByExercise[exerciseId] ??= []).add(row);
    }

    return [
      for (final sessionRow in sessionRows)
        _sessionFromGrouped(
          sessionRow: sessionRow,
          exerciseRows: exercisesBySession[sessionRow['local_id'] as String] ??
              const [],
          setsByExerciseId: setsByExercise,
        ),
    ];
  }

  static TrainingSession _sessionFromGrouped({
    required Map<String, dynamic> sessionRow,
    required List<Map<String, dynamic>> exerciseRows,
    required Map<String, List<Map<String, dynamic>>> setsByExerciseId,
  }) {
    return TrainingSession(
      id: sessionRow['local_id'] as String,
      serverId: sessionRow['server_id'] as String?,
      planLocalId: sessionRow['plan_local_id'] as String?,
      planServerId: sessionRow['plan_server_id'] as String?,
      planName: sessionRow['plan_name'] as String,
      status: decodeStatus(sessionRow['status'] as String),
      note: sessionRow['note'] as String?,
      startedAt: decodeDate(sessionRow['started_at'])!,
      finishedAt: decodeDate(sessionRow['finished_at']),
      sharedToProfile: ((sessionRow['shared_to_profile'] as int?) ?? 0) == 1,
      exercises: [
        for (final exerciseRow in exerciseRows)
          TrainingSessionExercise(
            id: exerciseRow['local_id'] as String,
            exerciseId:
                (exerciseRow['exercise_local_id'] as String?) ??
                (exerciseRow['exercise_server_id'] as String?) ??
                '',
            exerciseName: exerciseRow['exercise_name'] as String,
            exerciseMuscles: decodeStrings(
              exerciseRow['exercise_muscles'] as String,
            ),
            exerciseCategory: exerciseRow['exercise_category'] as String,
            exerciseImageUrl: exerciseRow['exercise_image_url'] as String?,
            sets: [
              for (final set
                  in setsByExerciseId[exerciseRow['local_id'] as String] ??
                      const <Map<String, dynamic>>[])
                TrainingSessionSet(
                  id: set['local_id'] as String,
                  plannedWeight: set['planned_weight'] as String?,
                  plannedReps: set['planned_reps'] as String? ?? '',
                  plannedRir: set['planned_rir'] as String?,
                  plannedTempo: set['planned_tempo'] as String?,
                  actualWeight: set['actual_weight'] as String?,
                  actualReps: set['actual_reps'] as String?,
                  actualRir: set['actual_rir'] as String?,
                  actualTempo: set['actual_tempo'] as String?,
                  completed: ((set['completed'] as int?) ?? 0) == 1,
                  completedAt: decodeDate(set['completed_at']),
                ),
            ],
          ),
      ],
      pendingOp: sessionRow['pending_op'] as String?,
    );
  }

  static Future<void> upsert(
    DatabaseExecutor db,
    TrainingSession session, {
    String? serverId,
    String? pendingOp,
    bool clearPendingOp = false,
  }) async {
    await _inTransaction(db, (txn) async {
      final old = await txn.query(
        ExerciseDatabase.tableTrainingSessions,
        where: 'local_id = ?',
        whereArgs: [session.id],
        limit: 1,
      );
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await txn.insert(
        ExerciseDatabase.tableTrainingSessions,
        {
          'local_id': session.id,
          'server_id': serverId ?? session.serverId,
          'plan_local_id': session.planLocalId,
          'plan_server_id': session.planServerId,
          'plan_name': session.planName,
          'status': session.status.name,
          'note': session.note,
          'started_at': encodeDate(session.startedAt),
          'finished_at': encodeDate(session.finishedAt),
          'shared_to_profile': session.sharedToProfile ? 1 : 0,
          'created_at': old.isEmpty ? now : old.first['created_at'],
          'updated_at': now,
          'pending_op': clearPendingOp ? null : (pendingOp ?? session.pendingOp),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _replaceChildrenIn(txn, session);
    });
  }

  /// Removes all rows for [sessionLocalId] (session, exercises, sets).
  static Future<void> deleteSession(Database db, String sessionLocalId) async {
    await db.transaction((txn) async {
      final oldExercises = await txn.query(
        ExerciseDatabase.tableTrainingSessionExercises,
        columns: ['local_id'],
        where: 'session_local_id = ?',
        whereArgs: [sessionLocalId],
      );
      await _deleteIn(
        txn,
        ExerciseDatabase.tableTrainingSessionSets,
        column: 'session_exercise_local_id',
        ids: [
          for (final old in oldExercises) old['local_id'] as String,
        ],
      );
      await txn.delete(
        ExerciseDatabase.tableTrainingSessionExercises,
        where: 'session_local_id = ?',
        whereArgs: [sessionLocalId],
      );
      await txn.delete(
        ExerciseDatabase.tableTrainingSessions,
        where: 'local_id = ?',
        whereArgs: [sessionLocalId],
      );
    });
  }

  static Future<void> replaceChildren(
    DatabaseExecutor db,
    TrainingSession session, {
    Map<String, String>? exerciseServerIdsByLocalId,
    Map<String, String>? setServerIdsByLocalId,
  }) {
    return _inTransaction(
      db,
      (txn) => _replaceChildrenIn(
        txn,
        session,
        exerciseServerIdsByLocalId: exerciseServerIdsByLocalId,
        setServerIdsByLocalId: setServerIdsByLocalId,
      ),
    );
  }

  static Future<void> _replaceChildrenIn(
    DatabaseExecutor db,
    TrainingSession session, {
    Map<String, String>? exerciseServerIdsByLocalId,
    Map<String, String>? setServerIdsByLocalId,
  }) async {
    final oldExercises = await db.query(
      ExerciseDatabase.tableTrainingSessionExercises,
      columns: ['local_id'],
      where: 'session_local_id = ?',
      whereArgs: [session.id],
    );
    await _deleteIn(
      db,
      ExerciseDatabase.tableTrainingSessionSets,
      column: 'session_exercise_local_id',
      ids: [
        for (final old in oldExercises) old['local_id'] as String,
      ],
    );
    await db.delete(
      ExerciseDatabase.tableTrainingSessionExercises,
      where: 'session_local_id = ?',
      whereArgs: [session.id],
    );

    final batch = db.batch();
    for (final entry in session.exercises.asMap().entries) {
      final exercise = entry.value;
      batch.insert(ExerciseDatabase.tableTrainingSessionExercises, {
        'local_id': exercise.id,
        'server_id': exerciseServerIdsByLocalId?[exercise.id],
        'session_local_id': session.id,
        'exercise_local_id': exercise.exerciseId,
        'exercise_server_id': null,
        'exercise_name': exercise.exerciseName,
        'exercise_muscles': encodeStrings(exercise.exerciseMuscles),
        'exercise_category': exercise.exerciseCategory,
        'exercise_image_url': exercise.exerciseImageUrl,
        'position': entry.key,
      });
      for (final setEntry in exercise.sets.asMap().entries) {
        final set = setEntry.value;
        batch.insert(ExerciseDatabase.tableTrainingSessionSets, {
          'local_id': set.id,
          'server_id': setServerIdsByLocalId?[set.id],
          'session_exercise_local_id': exercise.id,
          'position': setEntry.key,
          'planned_weight': set.plannedWeight,
          'planned_reps': set.plannedReps,
          'planned_rir': set.plannedRir,
          'planned_tempo': set.plannedTempo,
          'actual_weight': set.actualWeight,
          'actual_reps': set.actualReps,
          'actual_rir': set.actualRir,
          'actual_tempo': set.actualTempo,
          'completed': set.completed ? 1 : 0,
          'completed_at': encodeDate(set.completedAt),
        });
      }
    }
    await batch.commit(noResult: true);
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
