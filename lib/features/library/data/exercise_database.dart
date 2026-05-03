import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Singleton that owns the SQLite connection and schema migrations.
class ExerciseDatabase {
  ExerciseDatabase._();
  static final ExerciseDatabase instance = ExerciseDatabase._();

  Database? _db;

  static const _dbName = 'gym_library.db';
  static const _dbVersion = 1;

  static const tableExercises = 'exercises';

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableExercises (
        id            TEXT PRIMARY KEY,
        name          TEXT NOT NULL,
        muscles       TEXT NOT NULL,
        category      TEXT NOT NULL,
        is_favourite  INTEGER NOT NULL DEFAULT 0,
        is_mine       INTEGER NOT NULL DEFAULT 0,
        created_at    INTEGER NOT NULL
      )
    ''');
  }

  // Placeholder for future migrations.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
