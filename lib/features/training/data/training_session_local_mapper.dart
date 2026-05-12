import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../library/data/exercise_database.dart';
import '../domain/models/training_session.dart';

class TrainingSessionLocalMapper {
  static String encodeStrings(List<String> values) => jsonEncode(values);

  static List<String> decodeStrings(String raw) =>
      (jsonDecode(raw) as List).map((value) => value as String).toList();

  static int? encodeDate(DateTime? value) => value?.toUtc().millisecondsSinceEpoch;

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
    Database db,
    Map<String, dynamic> sessionRow,
  ) async {
    final exerciseRows = await db.query(
      ExerciseDatabase.tableTrainingSessionExercises,
      where: 'session_local_id = ?',
      whereArgs: [sessionRow['local_id']],
      orderBy: 'position ASC',
    );
    final exercises = <TrainingSessionExercise>[];
    for (final exerciseRow in exerciseRows) {
      final setRows = await db.query(
        ExerciseDatabase.tableTrainingSessionSets,
        where: 'session_exercise_local_id = ?',
        whereArgs: [exerciseRow['local_id']],
        orderBy: 'position ASC',
      );
      exercises.add(
        TrainingSessionExercise(
          id: exerciseRow['local_id'] as String,
          exerciseId: (exerciseRow['exercise_local_id'] as String?) ??
              (exerciseRow['exercise_server_id'] as String?) ??
              '',
          exerciseName: exerciseRow['exercise_name'] as String,
          exerciseMuscles:
              decodeStrings(exerciseRow['exercise_muscles'] as String),
          exerciseCategory: exerciseRow['exercise_category'] as String,
          exerciseImageUrl: exerciseRow['exercise_image_url'] as String?,
          sets: setRows
              .map(
                (set) => TrainingSessionSet(
                  id: set['local_id'] as String,
                  plannedWeight: set['planned_weight'] as String?,
                  plannedReps: set['planned_reps'] as String? ?? '',
                  plannedRir: set['planned_rir'] as String?,
                  plannedTempo: set['planned_tempo'] as String?,
                  actualWeight: set['actual_weight'] as String?,
                  actualReps: set['actual_reps'] as String?,
                  actualRir: set['actual_rir'] as String?,
                  completed: ((set['completed'] as int?) ?? 0) == 1,
                  completedAt: decodeDate(set['completed_at']),
                ),
              )
              .toList(),
        ),
      );
    }

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
      exercises: exercises,
      pendingOp: sessionRow['pending_op'] as String?,
    );
  }

  static Future<void> upsert(
    Database db,
    TrainingSession session, {
    String? serverId,
    String? pendingOp,
    bool clearPendingOp = false,
  }) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final old = await db.query(
      ExerciseDatabase.tableTrainingSessions,
      where: 'local_id = ?',
      whereArgs: [session.id],
      limit: 1,
    );
    await db.insert(
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
        'created_at': old.isEmpty ? now : old.first['created_at'],
        'updated_at': now,
        'pending_op': clearPendingOp ? null : (pendingOp ?? session.pendingOp),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await replaceChildren(db, session);
  }

  static Future<void> replaceChildren(
    Database db,
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
    for (final old in oldExercises) {
      await db.delete(
        ExerciseDatabase.tableTrainingSessionSets,
        where: 'session_exercise_local_id = ?',
        whereArgs: [old['local_id']],
      );
    }
    await db.delete(
      ExerciseDatabase.tableTrainingSessionExercises,
      where: 'session_local_id = ?',
      whereArgs: [session.id],
    );

    for (final entry in session.exercises.asMap().entries) {
      final exercise = entry.value;
      await db.insert(ExerciseDatabase.tableTrainingSessionExercises, {
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
        await db.insert(ExerciseDatabase.tableTrainingSessionSets, {
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
          'completed': set.completed ? 1 : 0,
          'completed_at': encodeDate(set.completedAt),
        });
      }
    }
  }
}
