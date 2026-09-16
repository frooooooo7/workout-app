import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Manages a single SQLite connection for the exercise cache.
///
/// Not a singleton — create one instance per user (keyed by [dbName]).
/// [ServiceLocator] is responsible for creating and re-creating this when the
/// authenticated user changes.
///
/// Use [run] for all DB access so [close] can wait for in-flight work safely.
///
/// [directoryOverride] — absolute directory for the DB file (tests only).
class ExerciseDatabase {
  ExerciseDatabase(this._dbName, {String? directoryOverride})
    : _directoryOverride = directoryOverride;

  final String _dbName;
  final String? _directoryOverride;

  Database? _db;

  bool _isClosing = false;
  int _activeOps = 0;
  Completer<void>? _closeWaiter;

  static const _dbVersion = 11;
  static const tableExercises = 'exercises';
  static const tableOutboxLog = 'outbox_log';
  static const tableTrainingPlans = 'training_plans';
  static const tableTrainingPlanExercises = 'training_plan_exercises';
  static const tableTrainingPlanSets = 'training_plan_sets';
  static const tableTrainingHistoryListCache = 'training_history_list_cache';
  static const tableTrainingHistoryDetailCache =
      'training_history_detail_cache';
  static const tableTrainingSessions = 'training_sessions';
  static const tableTrainingSessionExercises = 'training_session_exercises';
  static const tableTrainingSessionSets = 'training_session_sets';

  /// Klucz → wartość dla silników synchronizacji (np. znacznik ostatniego
  /// pobrania sesji). Baza jest per użytkownik, więc stan też.
  static const tableSyncState = 'sync_state';

  /// Tabele z kolejką wysyłki (`pending_op`) i kolumną `sync_error`.
  static const syncedTables = [
    tableExercises,
    tableTrainingPlans,
    tableTrainingSessions,
  ];

  static const _tmpV3Table = 'exercises_v3_tmp';

  Future<Database> get db async {
    if (_isClosing) {
      throw StateError('ExerciseDatabase is closing');
    }
    _db ??= await _open();
    return _db!;
  }

  /// Wraps database work so [close] waits until all tracked operations finish.
  Future<T> run<T>(Future<T> Function(Database database) action) async {
    if (_isClosing) {
      throw StateError('ExerciseDatabase is closing');
    }
    final database = await db;
    _activeOps++;
    try {
      return await action(database);
    } finally {
      _activeOps--;
      _maybeCompleteCloseWait();
    }
  }

  void _maybeCompleteCloseWait() {
    if (_activeOps == 0 && _closeWaiter != null && !_closeWaiter!.isCompleted) {
      _closeWaiter!.complete();
    }
  }

  // ── Sync bookkeeping ──────────────────────────────────────────────────────

  /// Zapisuje nieudaną próbę wysyłki: jeden wiersz na (`local_id`, `op`)
  /// z licznikiem prób — wcześniej każda porażka dokładała nowy wiersz.
  Future<void> recordSyncAttemptFailure({
    required String localId,
    required String op,
    required String message,
  }) {
    return run((db) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final updated = await db.rawUpdate(
        'UPDATE $tableOutboxLog '
        'SET attempts = attempts + 1, last_error = ?, created_at = ? '
        'WHERE local_id = ? AND op = ?',
        [message, now, localId, op],
      );
      if (updated > 0) return;
      await db.insert(tableOutboxLog, {
        'local_id': localId,
        'op': op,
        'attempts': 1,
        'last_error': message,
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Czyści historię porażek po udanej wysyłce wiersza.
  Future<void> clearSyncAttempts(String localId) {
    return run((db) async {
      await db.delete(
        tableOutboxLog,
        where: 'local_id = ?',
        whereArgs: [localId],
      );
    });
  }

  /// Oznacza wiersz jako odrzucony przez serwer — automatyczne ponawianie go
  /// pomija, dopóki użytkownik go nie zmieni albo nie wymusi synchronizacji.
  Future<void> markSyncRejected({
    required String table,
    required String localId,
    required String reason,
  }) {
    return run((db) async {
      await db.update(
        table,
        {'sync_error': reason},
        where: 'local_id = ?',
        whereArgs: [localId],
      );
    });
  }

  /// Przywraca odrzucone wiersze do kolejki (ręczne „Synchronizuj teraz”).
  Future<void> clearSyncErrors() {
    return run((db) async {
      for (final table in syncedTables) {
        await db.update(
          table,
          {'sync_error': null},
          where: 'sync_error IS NOT NULL',
        );
      }
    });
  }

  /// Ile zmian czeka na wysłanie i ile serwer odrzucił. Puste sesje nie są
  /// wysyłane, więc ich nie liczymy.
  Future<({int pending, int failed})> countSyncBacklog() {
    return run((db) async {
      final rows = await db.rawQuery('''
        SELECT
          (SELECT COUNT(*) FROM $tableExercises
             WHERE (pending_op IS NOT NULL OR is_favourite_dirty = 1)
               AND sync_error IS NULL)
          + (SELECT COUNT(*) FROM $tableTrainingPlans
             WHERE pending_op IS NOT NULL AND sync_error IS NULL)
          + (SELECT COUNT(*) FROM $tableTrainingSessions s
             WHERE s.pending_op IS NOT NULL AND s.sync_error IS NULL
               AND (s.pending_op = 'delete' OR EXISTS (
                 SELECT 1 FROM $tableTrainingSessionExercises e
                 WHERE e.session_local_id = s.local_id
               ))) AS pending,
          (SELECT COUNT(*) FROM $tableExercises WHERE sync_error IS NOT NULL)
          + (SELECT COUNT(*) FROM $tableTrainingPlans WHERE sync_error IS NOT NULL)
          + (SELECT COUNT(*) FROM $tableTrainingSessions WHERE sync_error IS NOT NULL)
            AS failed
      ''');
      final row = rows.first;
      return (
        pending: (row['pending'] as int?) ?? 0,
        failed: (row['failed'] as int?) ?? 0,
      );
    });
  }

  Future<String?> readSyncState(String key) {
    return run((db) async {
      final rows = await db.query(
        tableSyncState,
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first['value'] as String?;
    });
  }

  Future<void> writeSyncState(String key, String? value) {
    return run((db) async {
      if (value == null) {
        await db.delete(tableSyncState, where: 'key = ?', whereArgs: [key]);
        return;
      }
      await db.insert(tableSyncState, {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  // ── Schema ────────────────────────────────────────────────────────────────

  Future<Database> _open() async {
    final dbPath = _directoryOverride ?? await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createOutboxLog(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableOutboxLog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_id TEXT NOT NULL,
        op TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await _createOutboxLogIndex(db);
  }

  Future<void> _createOutboxLogIndex(Database db) async {
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS outbox_log_local_op_idx '
      'ON $tableOutboxLog (local_id, op)',
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableExercises (
        local_id TEXT PRIMARY KEY NOT NULL,
        server_id TEXT UNIQUE,
        name TEXT NOT NULL,
        muscles TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        image_url TEXT,
        is_favourite INTEGER NOT NULL DEFAULT 0,
        is_mine INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        pending_op TEXT,
        is_favourite_dirty INTEGER NOT NULL DEFAULT 0,
        local_image_bytes BLOB,
        local_image_filename TEXT,
        sync_error TEXT
      )
    ''');
    await _createOutboxLog(db);
    await _createTrainingPlanTables(db);
    await _createTrainingHistoryTables(db);
    await _createTrainingSessionTables(db);
    await _createPerformanceIndexes(db);
    await _createSyncStateTable(db);
  }

  Future<void> _createSyncStateTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSyncState (
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  /// Indeksy pod odczyty historii / planów i kolejkę sync — bez nich
  /// `WHERE session_local_id = ?` i `pending_op IS NOT NULL` skanują tabele.
  Future<void> _createPerformanceIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS tpe_plan_idx '
      'ON $tableTrainingPlanExercises(plan_local_id, position)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS tps_plan_ex_idx '
      'ON $tableTrainingPlanSets(plan_exercise_local_id, position)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS tse_session_idx '
      'ON $tableTrainingSessionExercises(session_local_id, position)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS tss_session_ex_idx '
      'ON $tableTrainingSessionSets(session_exercise_local_id, position)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ts_status_started_idx '
      'ON $tableTrainingSessions(status, started_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ts_pending_idx '
      'ON $tableTrainingSessions(pending_op) WHERE pending_op IS NOT NULL',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS tp_pending_idx '
      'ON $tableTrainingPlans(pending_op) WHERE pending_op IS NOT NULL',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS ex_pending_idx '
      'ON $tableExercises(pending_op, is_favourite_dirty) '
      'WHERE pending_op IS NOT NULL OR is_favourite_dirty = 1',
    );
  }

  Future<void> _createTrainingPlanTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTrainingPlans (
        local_id TEXT PRIMARY KEY NOT NULL,
        server_id TEXT UNIQUE,
        name TEXT NOT NULL,
        note TEXT,
        selected_days TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        pending_op TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        sync_error TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTrainingPlanExercises (
        local_id TEXT PRIMARY KEY NOT NULL,
        server_id TEXT UNIQUE,
        plan_local_id TEXT NOT NULL,
        exercise_local_id TEXT NOT NULL,
        exercise_server_id TEXT,
        position INTEGER NOT NULL,
        FOREIGN KEY(plan_local_id) REFERENCES $tableTrainingPlans(local_id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTrainingPlanSets (
        local_id TEXT PRIMARY KEY NOT NULL,
        server_id TEXT UNIQUE,
        plan_exercise_local_id TEXT NOT NULL,
        position INTEGER NOT NULL,
        weight TEXT,
        reps TEXT NOT NULL DEFAULT '',
        rir TEXT,
        tempo TEXT,
        FOREIGN KEY(plan_exercise_local_id) REFERENCES $tableTrainingPlanExercises(local_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createTrainingHistoryTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTrainingHistoryListCache (
        cache_key TEXT PRIMARY KEY NOT NULL,
        payload_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTrainingHistoryDetailCache (
        session_id TEXT PRIMARY KEY NOT NULL,
        payload_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createTrainingSessionTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTrainingSessions (
        local_id TEXT PRIMARY KEY NOT NULL,
        server_id TEXT UNIQUE,
        plan_local_id TEXT,
        plan_server_id TEXT,
        plan_name TEXT NOT NULL,
        status TEXT NOT NULL,
        note TEXT,
        started_at INTEGER NOT NULL,
        finished_at INTEGER,
        shared_to_profile INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        pending_op TEXT,
        sync_error TEXT,
        server_updated_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTrainingSessionExercises (
        local_id TEXT PRIMARY KEY NOT NULL,
        server_id TEXT UNIQUE,
        session_local_id TEXT NOT NULL,
        exercise_local_id TEXT,
        exercise_server_id TEXT,
        exercise_name TEXT NOT NULL,
        exercise_muscles TEXT NOT NULL,
        exercise_category TEXT NOT NULL,
        exercise_image_url TEXT,
        position INTEGER NOT NULL,
        FOREIGN KEY(session_local_id) REFERENCES $tableTrainingSessions(local_id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTrainingSessionSets (
        local_id TEXT PRIMARY KEY NOT NULL,
        server_id TEXT UNIQUE,
        session_exercise_local_id TEXT NOT NULL,
        position INTEGER NOT NULL,
        planned_weight TEXT,
        planned_reps TEXT NOT NULL DEFAULT '',
        planned_rir TEXT,
        planned_tempo TEXT,
        actual_weight TEXT,
        actual_reps TEXT,
        actual_rir TEXT,
        actual_tempo TEXT,
        completed INTEGER NOT NULL DEFAULT 0,
        completed_at INTEGER,
        FOREIGN KEY(session_exercise_local_id) REFERENCES $tableTrainingSessionExercises(local_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _migrateToV3(Database db) async {
    await db.execute('''
      CREATE TABLE $_tmpV3Table (
        local_id TEXT PRIMARY KEY NOT NULL,
        server_id TEXT UNIQUE,
        name TEXT NOT NULL,
        muscles TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        image_url TEXT,
        is_favourite INTEGER NOT NULL DEFAULT 0,
        is_mine INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        pending_op TEXT,
        is_favourite_dirty INTEGER NOT NULL DEFAULT 0,
        local_image_bytes BLOB,
        local_image_filename TEXT
      )
    ''');

    await db.execute('''
      INSERT INTO $_tmpV3Table (
        local_id, server_id, name, muscles, category, description, image_url,
        is_favourite, is_mine, created_at, pending_op, is_favourite_dirty,
        local_image_bytes, local_image_filename
      )
      SELECT
        id,
        id,
        name,
        muscles,
        category,
        COALESCE(description, ''),
        image_url,
        is_favourite,
        is_mine,
        created_at,
        NULL,
        0,
        NULL,
        NULL
      FROM $tableExercises
    ''');

    await db.execute('DROP TABLE $tableExercises');
    await db.execute('ALTER TABLE $_tmpV3Table RENAME TO $tableExercises');
    await _createOutboxLog(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $tableExercises ADD COLUMN description TEXT NOT NULL DEFAULT ""',
      );
      await db.execute('ALTER TABLE $tableExercises ADD COLUMN image_url TEXT');
    }
    if (oldVersion < 3) {
      await _migrateToV3(db);
    }
    if (oldVersion < 4) {
      await _createTrainingPlanTables(db);
    }
    if (oldVersion < 5) {
      await _createTrainingHistoryTables(db);
    }
    if (oldVersion < 6) {
      await _createTrainingSessionTables(db);
    }
    if (oldVersion == 6) {
      await _createTrainingHistoryTables(db);
    }
    if (oldVersion < 8) {
      await _addColumnIfMissing(
        db,
        table: tableTrainingSessions,
        column: 'shared_to_profile',
        definition: 'INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 9) {
      for (final table in syncedTables) {
        await _addColumnIfMissing(
          db,
          table: table,
          column: 'sync_error',
          definition: 'TEXT',
        );
      }
      // Stare wersje dopisywały wiersz przy każdej porażce — zostaw ostatni.
      await db.execute('''
        DELETE FROM $tableOutboxLog
        WHERE id NOT IN (
          SELECT MAX(id) FROM $tableOutboxLog GROUP BY local_id, op
        )
      ''');
      await _createOutboxLogIndex(db);
    }
    if (oldVersion < 10) {
      await _createPerformanceIndexes(db);
    }
    if (oldVersion < 11) {
      await _createSyncStateTable(db);
      // `updatedAt` z serwera przy ostatnim pobraniu — pull pomija sesje,
      // które już ma w tej wersji (okno zakładki odsyła je ponownie).
      await _addColumnIfMissing(
        db,
        table: tableTrainingSessions,
        column: 'server_updated_at',
        definition: 'INTEGER',
      );
    }
  }

  /// `ALTER TABLE ... ADD COLUMN` bez ryzyka duplikatu — tabela utworzona
  /// w tej samej ścieżce upgrade'u (np. `oldVersion < 6`) ma już nową kolumnę.
  Future<void> _addColumnIfMissing(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (exists) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  Future<void> close() async {
    final handle = _db;
    if (handle == null) {
      return;
    }
    _isClosing = true;
    if (_activeOps > 0) {
      _closeWaiter = Completer<void>();
      await _closeWaiter!.future;
    }
    await handle.close();
    _db = null;
    _isClosing = false;
    _closeWaiter = null;
  }
}
