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
  ExerciseDatabase(
    this._dbName, {
    String? directoryOverride,
  }) : _directoryOverride = directoryOverride;

  final String _dbName;
  final String? _directoryOverride;

  Database? _db;

  bool _isClosing = false;
  int _activeOps = 0;
  Completer<void>? _closeWaiter;

  static const _dbVersion = 5;
  static const tableExercises = 'exercises';
  static const tableOutboxLog = 'outbox_log';
  static const tableTrainingPlans = 'training_plans';
  static const tableTrainingPlanExercises = 'training_plan_exercises';
  static const tableTrainingPlanSets = 'training_plan_sets';
  static const tableTrainingSessions = 'training_sessions';
  static const tableTrainingSessionExercises = 'training_session_exercises';
  static const tableTrainingSessionSets = 'training_session_sets';

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
    if (_activeOps == 0 &&
        _closeWaiter != null &&
        !_closeWaiter!.isCompleted) {
      _closeWaiter!.complete();
    }
  }

  Future<Database> _open() async {
    final dbPath =
        _directoryOverride ?? await getDatabasesPath();
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
        local_image_filename TEXT
      )
    ''');
    await _createOutboxLog(db);
    await _createTrainingPlanTables(db);
    await _createTrainingSessionTables(db);
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
        is_deleted INTEGER NOT NULL DEFAULT 0
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
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        pending_op TEXT
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
      await db.execute(
        'ALTER TABLE $tableExercises ADD COLUMN image_url TEXT',
      );
    }
    if (oldVersion < 3) {
      await _migrateToV3(db);
    }
    if (oldVersion < 4) {
      await _createTrainingPlanTables(db);
    }
    if (oldVersion < 5) {
      await _createTrainingSessionTables(db);
    }
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
