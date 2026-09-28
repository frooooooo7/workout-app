import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/training/data/local_training_stats_repository.dart';
import 'package:gym/features/training/data/training_session_local_history.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dir;
  late ExerciseDatabase db;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('gym_stats_repo');
    db = ExerciseDatabase('stats.db', directoryOverride: dir.path);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<void> insertSessions(int count, {String status = 'completed'}) {
    return db.run((db) async {
      final batch = db.batch();
      final base = DateTime.utc(2024, 1, 1);
      for (var i = 0; i < count; i++) {
        final id = '$status-$i';
        final started = base.add(Duration(days: i)).millisecondsSinceEpoch;
        batch.insert(ExerciseDatabase.tableTrainingSessions, {
          'local_id': id,
          'server_id': 'srv-$id',
          'plan_name': 'Push',
          'status': status,
          'started_at': started,
          'finished_at': started + 3600000,
          'created_at': started,
          'updated_at': started,
        });
        batch.insert(ExerciseDatabase.tableTrainingSessionExercises, {
          'local_id': 'ex-$id',
          'session_local_id': id,
          'exercise_name': 'Wyciskanie',
          'exercise_muscles': '["chest"]',
          'exercise_category': 'compound',
          'position': 0,
        });
        batch.insert(ExerciseDatabase.tableTrainingSessionSets, {
          'local_id': 'set-$id',
          'session_exercise_local_id': 'ex-$id',
          'position': 0,
          'actual_weight': '80',
          'actual_reps': '5',
          'completed': 1,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  test('allCompletedSessions is not capped like the history list', () async {
    await insertSessions(130);
    await insertSessions(3, status: 'cancelled');
    var reads = 0;
    final repository = LocalTrainingStatsRepository(
      TrainingSessionLocalHistory(db),
      onRead: () => reads++,
    );

    final all = await repository.allCompletedSessions();
    expect(all, hasLength(130));
    expect(all.first.startedAt.isAfter(all.last.startedAt), isTrue);
    expect(all.first.exercises.single.sets.single.actualWeight, '80');
    expect(reads, 1);

    // Lista historii nadal ma limit.
    final recent = await repository.completedSessionsSince(DateTime.utc(2000));
    expect(recent, hasLength(100));
  });
}
