import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../library/data/exercise_database.dart';

class TrainingHistoryLocalCache {
  const TrainingHistoryLocalCache(this._localDb);

  final ExerciseDatabase _localDb;

  Future<void> saveListResponse({
    required String cacheKey,
    required Map<String, dynamic> payload,
    required DateTime updatedAt,
  }) async {
    await _localDb.run((db) {
      return db.insert(
        ExerciseDatabase.tableTrainingHistoryListCache,
        {
          'cache_key': cacheKey,
          'payload_json': jsonEncode(payload),
          'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<Map<String, dynamic>?> readListResponse(String cacheKey) async {
    return _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingHistoryListCache,
        where: 'cache_key = ?',
        whereArgs: [cacheKey],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final payload = rows.first['payload_json'] as String?;
      if (payload == null || payload.isEmpty) return null;
      return jsonDecode(payload) as Map<String, dynamic>;
    });
  }

  Future<void> saveSessionDetail({
    required String sessionId,
    required Map<String, dynamic> payload,
    required DateTime updatedAt,
  }) async {
    await _localDb.run((db) {
      return db.insert(
        ExerciseDatabase.tableTrainingHistoryDetailCache,
        {
          'session_id': sessionId,
          'payload_json': jsonEncode(payload),
          'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<Map<String, dynamic>?> readSessionDetail(String sessionId) async {
    return _localDb.run((db) async {
      final rows = await db.query(
        ExerciseDatabase.tableTrainingHistoryDetailCache,
        where: 'session_id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final payload = rows.first['payload_json'] as String?;
      if (payload == null || payload.isEmpty) return null;
      return jsonDecode(payload) as Map<String, dynamic>;
    });
  }
}

