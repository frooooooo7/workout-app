import 'package:sqflite/sqflite.dart';

import '../../library/data/exercise_database.dart';

/// Znacznik „kolejność planów czeka na serwer”. Sama kolejność leży w kolumnie
/// `sort_order` planów; tu jest tylko flaga z wersją zapisu (tabela
/// `sync_state`), żeby przesunięcie nie robiło z planów zmian do wysłania.
abstract final class PendingPlanOrderStore {
  static const _key = 'plan_order_pending';

  static int _lastVersion = 0;

  /// Rosnący znacznik zapisu — dwa przesunięcia w tej samej chwili nie mogą
  /// dostać tej samej wersji.
  static int _nextVersion() {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    _lastVersion = now > _lastVersion ? now : _lastVersion + 1;
    return _lastVersion;
  }

  static Future<void> mark(DatabaseExecutor db) async {
    await db.insert(ExerciseDatabase.tableSyncState, {
      'key': _key,
      'value': '${_nextVersion()}',
      'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Wersja oczekującego przesunięcia albo `null`, gdy nic nie czeka.
  static Future<String?> version(DatabaseExecutor db) async {
    final rows = await db.query(
      ExerciseDatabase.tableSyncState,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  /// Zdejmuje flagę — tylko jeśli od wysyłki nie zapisano nowszego przesunięcia
  /// ([onlyVersion]).
  static Future<void> clear(DatabaseExecutor db, {String? onlyVersion}) async {
    await db.delete(
      ExerciseDatabase.tableSyncState,
      where: onlyVersion == null ? 'key = ?' : 'key = ? AND value = ?',
      whereArgs: [_key, ?onlyVersion],
    );
  }
}
