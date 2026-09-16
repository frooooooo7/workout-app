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

  /// Usuwa sesje o podanych id (lokalnych lub serwerowych) z cache listy
  /// i szczegółów — usunięty trening nie może wrócić z pamięci podręcznej.
  Future<void> removeSessions(Set<String> sessionIds) async {
    final ids = sessionIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return;
    await _localDb.run((db) async {
      await db.transaction((txn) async {
        final idList = ids.toList();
        final placeholders = List.filled(idList.length, '?').join(', ');
        await txn.delete(
          ExerciseDatabase.tableTrainingHistoryDetailCache,
          where: 'session_id IN ($placeholders)',
          whereArgs: idList,
        );
        final rows = await txn.query(
          ExerciseDatabase.tableTrainingHistoryListCache,
        );
        for (final row in rows) {
          final raw = row['payload_json'] as String?;
          if (raw == null || raw.isEmpty) continue;
          Map<String, dynamic> payload;
          try {
            payload = jsonDecode(raw) as Map<String, dynamic>;
          } catch (_) {
            continue;
          }
          final items = payload['items'];
          if (items is! List) continue;
          final kept = [
            for (final item in items)
              if (!(item is Map && ids.contains(item['id']))) item,
          ];
          if (kept.length == items.length) continue;
          payload['items'] = kept;
          await txn.update(
            ExerciseDatabase.tableTrainingHistoryListCache,
            {'payload_json': jsonEncode(payload)},
            where: 'cache_key = ?',
            whereArgs: [row['cache_key']],
          );
        }
      });
    });
  }
}
