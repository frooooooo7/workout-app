import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/library/data/exercise_dto.dart';
import 'package:gym/features/library/data/exercise_remote_data_source.dart';
import 'package:gym/features/library/data/offline_first_exercise_repository.dart';
import 'package:gym/features/library/data/sync/exercise_sync_engine.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('tracking mode and distance unit survive the local database', () async {
    final dir = await Directory.systemTemp.createTemp('gym_cardio');
    final edb = ExerciseDatabase('cardio.db', directoryOverride: dir.path);
    final api = ApiClient(
      baseUrl: 'http://127.0.0.1:9',
      getToken: () async => null,
    );
    final sync = ExerciseSyncEngine(
      remote: ExerciseRemoteDataSource(api),
      localDb: edb,
    );
    sync.stop();
    final repo = OfflineFirstExerciseRepository(localDb: edb, syncEngine: sync);

    final created = await repo.create(
      name: 'Wioślarz',
      muscles: const [MuscleGroup.back],
      category: ExerciseCategory.cardio,
      description: '',
      tracking: ExerciseTracking.durationDistance,
      distanceUnit: DistanceUnit.m,
    );

    await edb.run((db) async {
      final row = (await db.query(ExerciseDatabase.tableExercises)).single;
      final restored = ExerciseDto.fromMap(row).toDomain();
      expect(restored.id, created.id);
      expect(restored.tracking, ExerciseTracking.durationDistance);
      expect(restored.distanceUnit, DistanceUnit.m);
    });

    await edb.close();
    await dir.delete(recursive: true);
  });

  test(
    'exercise JSON reads the mode, and an older server means weight × reps',
    () {
      final base = {
        'id': '11111111-1111-4111-8111-111111111111',
        'name': 'Bieżnia',
        'muscles': ['quads'],
        'category': 'cardio',
        'description': '',
        'createdAt': '2024-01-01T00:00:00.000Z',
      };
      final legacy = ExerciseRemoteDataSource.fromJson(base);
      expect(legacy.tracking, ExerciseTracking.weightReps);
      expect(legacy.distanceUnit, DistanceUnit.km);

      final cardio = ExerciseRemoteDataSource.fromJson({
        ...base,
        'trackingType': 'duration_distance',
        'distanceUnit': 'm',
      });
      expect(cardio.tracking, ExerciseTracking.durationDistance);
      expect(cardio.distanceUnit, DistanceUnit.m);
    },
  );
}
