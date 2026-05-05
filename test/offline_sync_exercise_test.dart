import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/library/data/exercise_dto.dart';
import 'package:gym/features/library/data/exercise_remote_data_source.dart';
import 'package:gym/features/library/data/offline_first_exercise_repository.dart';
import 'package:gym/features/library/data/sync/exercise_sync_engine.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('ExerciseDatabase migrates v2→v3: local_id and server_id backfilled', () async {
    final dir = await Directory.systemTemp.createTemp('gym_v3_mig');
    final dbFileName = 'migrated.db';
    final absoluteDbPath = p.join(dir.path, dbFileName);

    await databaseFactory.deleteDatabase(absoluteDbPath);

    var legacyDb = await openDatabase(
      absoluteDbPath,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE exercises (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            muscles TEXT NOT NULL,
            category TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            image_url TEXT,
            is_favourite INTEGER NOT NULL DEFAULT 0,
            is_mine INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
    await legacyDb.insert('exercises', {
      'id': 'legacy-row-id',
      'name': 'X',
      'muscles': '["biceps"]',
      'category': 'isolation',
      'description': '',
      'image_url': null,
      'is_favourite': 0,
      'is_mine': 1,
      'created_at': 1700000000000,
    });
    await legacyDb.close();

    final edb = ExerciseDatabase(dbFileName, directoryOverride: dir.path);
    await edb.run((db) async {
      final rows = await db.query('exercises');
      expect(rows, hasLength(1));
      expect(rows.single['local_id'], 'legacy-row-id');
      expect(rows.single['server_id'], 'legacy-row-id');
      expect(rows.single['pending_op'], isNull);
    });
    await edb.close();
    await dir.delete(recursive: true);
  });

  test('OfflineFirstExerciseRepository.create writes pending_op offline', () async {
    final dir = await Directory.systemTemp.createTemp('gym_off');
    final dbName = 'off.db';
    final edb = ExerciseDatabase(dbName, directoryOverride: dir.path);
    final api = ApiClient(baseUrl: 'http://127.0.0.1:9', getToken: () async => null);
    final remote = ExerciseRemoteDataSource(api);
    final sync = ExerciseSyncEngine(remote: remote, localDb: edb);
    sync.stop();

    final repo = OfflineFirstExerciseRepository(
      localDb: edb,
      syncEngine: sync,
    );

    final created = await repo.create(
      name: 'Push-up',
      muscles: const [MuscleGroup.chest],
      category: ExerciseCategory.calisthenics,
      description: '',
    );

    expect(created.isPendingSync, true);

    await edb.run((db) async {
      final rows = await db.query(ExerciseDatabase.tableExercises);
      expect(rows, hasLength(1));
      expect(rows.single['pending_op'], 'create');
      expect(rows.single['local_id'], created.id);
    });

    await edb.close();
    await dir.delete(recursive: true);
  });

  test('delete pending create removes row without calling remote delete', () async {
    final dir = await Directory.systemTemp.createTemp('gym_del');
    final dbName = 'del.db';

    final recorded = <String>[];

    final remote = _SpyExerciseRemote(recorded);

    final edb = ExerciseDatabase(dbName, directoryOverride: dir.path);
    final sync = ExerciseSyncEngine(remote: remote, localDb: edb);
    sync.stop();

    final repo = OfflineFirstExerciseRepository(
      localDb: edb,
      syncEngine: sync,
    );

    final created = await repo.create(
      name: 'Tmp',
      muscles: const [MuscleGroup.abs],
      category: ExerciseCategory.calisthenics,
      description: '',
    );

    await repo.delete(created.id);

    await edb.run((db) async {
      final rows = await db.query(ExerciseDatabase.tableExercises);
      expect(rows, isEmpty);
      final logs = await db.query(ExerciseDatabase.tableOutboxLog);
      expect(logs.single['op'], 'skipped_pending_create');
    });

    expect(recorded.where((e) => e.startsWith('delete')), isEmpty);

    await edb.close();
    await dir.delete(recursive: true);
  });

  test('ExerciseSyncEngine.flush runs create before image upload', () async {
    final dir = await Directory.systemTemp.createTemp('gym_sync');
    final dbName = 'sync.db';
    final edb = ExerciseDatabase(dbName, directoryOverride: dir.path);

    final localId = '11111111-1111-4111-8111-111111111111';
    final dto = ExerciseDto.fromDomain(
      Exercise(
        id: localId,
        name: 'With pic',
        muscles: const [MuscleGroup.biceps],
        category: ExerciseCategory.isolation,
        description: '',
        isMine: true,
        createdAt: DateTime.utc(2024),
      ),
      pendingOp: 'create',
      localImageBytes: Uint8List.fromList([1, 2, 3]),
      localImageFilename: 'x.jpg',
    );

    await edb.run((db) async {
      await db.insert(ExerciseDatabase.tableExercises, dto.toMap());
    });

    final seqRemote = _SeqRemote();
    final sync = ExerciseSyncEngine(remote: seqRemote, localDb: edb);

    await sync.flush();

    final ci = seqRemote.log.indexOf('create');
    final ii = seqRemote.log.indexOf('image');
    expect(ci, greaterThanOrEqualTo(0));
    expect(ii, greaterThan(ci));

    await edb.close();
    await dir.delete(recursive: true);
  });
}

class _SpyExerciseRemote extends ExerciseRemoteDataSource {
  _SpyExerciseRemote(this.recorded)
      : super(ApiClient(baseUrl: 'http://127.0.0.1:9', getToken: () async => null));

  final List<String> recorded;

  @override
  Future<void> delete(String id) async {
    recorded.add('delete:$id');
  }
}

class _SeqRemote extends ExerciseRemoteDataSource {
  _SeqRemote() : super(ApiClient(baseUrl: 'http://127.0.0.1:9', getToken: () async => ''));

  final List<String> log = [];

  @override
  Future<List<Exercise>> getAll({
    MuscleGroup? muscleGroup,
    LibraryFilter? filter,
    String? query,
  }) async {
    log.add('getAll');
    return const [];
  }

  @override
  Future<Exercise> create({
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
    String? clientId,
  }) async {
    log.add('create');
    return Exercise(
      id: 'aaaaaaaa-bbbb-4ccc-bddd-eeeeeeeeeeee',
      name: name,
      muscles: muscles,
      category: category,
      description: description,
      imageUrl: null,
      isFavourite: false,
      isMine: true,
      createdAt: DateTime.utc(2024),
    );
  }

  @override
  Future<Exercise> uploadExerciseImage(
    String exerciseId,
    Uint8List bytes,
    String filename,
  ) async {
    log.add('image');
    return Exercise(
      id: exerciseId,
      name: 'With pic',
      muscles: const [MuscleGroup.biceps],
      category: ExerciseCategory.isolation,
      imageUrl: '/uploads/exercise-images/mock.jpg',
      isFavourite: false,
      isMine: true,
      createdAt: DateTime.utc(2024),
    );
  }

  @override
  Future<Exercise> update({
    required String id,
    required String name,
    required List<MuscleGroup> muscles,
    required ExerciseCategory category,
    required String description,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> delete(String id) async {
    log.add('delete');
  }

  @override
  Future<bool> toggleFavourite(String id) async {
    log.add('fav');
    return true;
  }
}
