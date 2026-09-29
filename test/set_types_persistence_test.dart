import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/training/data/local_previous_performance_repository.dart';
import 'package:gym/features/training/data/training_history_json.dart';
import 'package:gym/features/training/data/training_history_remote_data_source.dart';
import 'package:gym/features/training/data/training_session_local_mapper.dart';
import 'package:gym/features/training/data/training_session_remote_data_source.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

TrainingSessionSet _set(
  String id,
  String weight,
  String reps, {
  SetType type = SetType.normal,
  bool completed = true,
}) => TrainingSessionSet(
  id: id,
  setType: type,
  actualWeight: weight,
  actualReps: reps,
  completed: completed,
);

TrainingSessionExercise _exercise(
  String id,
  List<TrainingSessionSet> sets, {
  String exerciseId = 'bench',
  String name = 'Bench',
  String? note,
}) => TrainingSessionExercise(
  id: id,
  exerciseId: exerciseId,
  exerciseName: name,
  exerciseMuscles: const ['chest'],
  exerciseCategory: 'compound',
  note: note,
  sets: sets,
);

TrainingSession _session(
  String id,
  DateTime startedAt,
  List<TrainingSessionExercise> exercises, {
  TrainingSessionStatus status = TrainingSessionStatus.completed,
}) => TrainingSession(
  id: id,
  planName: 'Push',
  status: status,
  startedAt: startedAt,
  finishedAt: status == TrainingSessionStatus.active
      ? null
      : startedAt.add(const Duration(hours: 1)),
  exercises: exercises,
);

class _NoNetworkApi extends ApiClient {
  _NoNetworkApi() : super(baseUrl: 'http://test.local');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('set_types_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  group('local database', () {
    test(
      'a fresh database round-trips set types and the exercise note',
      () async {
        final db = ExerciseDatabase('fresh.db', directoryOverride: dir.path);
        final session = _session('s1', DateTime.utc(2026, 9, 1, 10), [
          _exercise('e1', [
            _set('a', '60', '10', type: SetType.warmup),
            _set('b', '100', '5'),
            _set('c', '100', '4', type: SetType.failure),
            _set('d', '80', '8', type: SetType.drop),
          ], note: 'Ławka o 1 dziurkę niżej'),
        ]);

        final loaded = await db.run((database) async {
          await TrainingSessionLocalMapper.upsert(database, session);
          final rows = await database.query(
            ExerciseDatabase.tableTrainingSessions,
          );
          return TrainingSessionLocalMapper.fromDb(database, rows.single);
        });

        final exercise = loaded!.exercises.single;
        expect(exercise.note, 'Ławka o 1 dziurkę niżej');
        expect(exercise.sets.map((s) => s.setType), [
          SetType.warmup,
          SetType.normal,
          SetType.failure,
          SetType.drop,
        ]);
        await db.close();
      },
    );

    test(
      'upgrading from v11 keeps existing rows as normal sets without a note',
      () async {
        final path = p.join(dir.path, 'legacy.db');
        final legacy = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 11,
            onCreate: (db, _) async {
              // Schemat sprzed v12: bez `set_type` i `note`.
              await db.execute('''
              CREATE TABLE training_sessions (
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
              CREATE TABLE training_session_exercises (
                local_id TEXT PRIMARY KEY NOT NULL,
                server_id TEXT UNIQUE,
                session_local_id TEXT NOT NULL,
                exercise_local_id TEXT,
                exercise_server_id TEXT,
                exercise_name TEXT NOT NULL,
                exercise_muscles TEXT NOT NULL,
                exercise_category TEXT NOT NULL,
                exercise_image_url TEXT,
                position INTEGER NOT NULL
              )
            ''');
              await db.execute('''
              CREATE TABLE training_session_sets (
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
                completed_at INTEGER
              )
            ''');
              await db.insert('training_sessions', {
                'local_id': 'old',
                'plan_name': 'Stary trening',
                'status': 'completed',
                'started_at': 1,
                'created_at': 1,
                'updated_at': 1,
              });
              await db.insert('training_session_exercises', {
                'local_id': 'old-e',
                'session_local_id': 'old',
                'exercise_name': 'Bench',
                'exercise_muscles': '["chest"]',
                'exercise_category': 'compound',
                'position': 0,
              });
              await db.insert('training_session_sets', {
                'local_id': 'old-s',
                'session_exercise_local_id': 'old-e',
                'position': 0,
                'actual_weight': '100',
                'actual_reps': '5',
                'completed': 1,
              });
            },
          ),
        );
        await legacy.close();

        final db = ExerciseDatabase('legacy.db', directoryOverride: dir.path);
        final loaded = await db.run((database) async {
          final rows = await database.query(
            ExerciseDatabase.tableTrainingSessions,
          );
          return TrainingSessionLocalMapper.fromDb(database, rows.single);
        });

        final exercise = loaded!.exercises.single;
        expect(exercise.note, isNull);
        expect(exercise.sets.single.setType, SetType.normal);
        expect(exercise.sets.single.actualWeight, '100');

        // Po migracji nowe wartości da się zapisać w tych samych tabelach.
        await db.run((database) async {
          await TrainingSessionLocalMapper.upsert(
            database,
            loaded.copyWith(
              exercises: [
                exercise.copyWith(
                  note: 'po migracji',
                  sets: [
                    exercise.sets.single.copyWith(setType: SetType.warmup),
                  ],
                ),
              ],
            ),
          );
        });
        final reloaded = await db.run((database) async {
          final rows = await database.query(
            ExerciseDatabase.tableTrainingSessions,
          );
          return TrainingSessionLocalMapper.fromDb(database, rows.single);
        });
        expect(reloaded!.exercises.single.note, 'po migracji');
        expect(reloaded.exercises.single.sets.single.setType, SetType.warmup);
        await db.close();
      },
    );
  });

  group('API payloads', () {
    late TrainingSessionRemoteDataSource remote;

    setUp(() => remote = TrainingSessionRemoteDataSource(_NoNetworkApi()));

    test('the request body sends setType and the exercise note', () {
      final body = remote.toBody(
        _session('s1', DateTime.utc(2026, 9, 1), [
          _exercise('e1', [
            _set('a', '60', '10', type: SetType.warmup),
            _set('b', '100', '5'),
          ], note: 'z pauzą'),
        ]),
        exerciseServerIdsByLocalId: const {},
      );

      final exercise = (body['exercises'] as List).single as Map;
      expect(exercise['note'], 'z pauzą');
      expect((exercise['sets'] as List).map((s) => (s as Map)['setType']), [
        'warmup',
        'normal',
      ]);
    });

    Map<String, dynamic> pageJson(Map<String, dynamic> exercise) => {
      'items': [
        {
          'id': 'srv-1',
          'clientId': 'loc-1',
          'planName': 'Push',
          'status': 'completed',
          'startedAt': '2026-09-01T10:00:00.000Z',
          'finishedAt': '2026-09-01T11:00:00.000Z',
          'exercises': [exercise],
        },
      ],
      'hasMore': false,
    };

    test('a server response with the new fields is parsed', () {
      final page = remote.historyPageFromJson(
        pageJson({
          'exerciseName': 'Bench',
          'exerciseMuscles': ['chest'],
          'exerciseCategory': 'compound',
          'note': 'z pauzą',
          'sets': [
            {'setType': 'warmup', 'plannedReps': ''},
            {'setType': 'drop', 'plannedReps': ''},
          ],
        }),
      );

      final exercise = page.items.single.session.exercises.single;
      expect(exercise.note, 'z pauzą');
      expect(exercise.sets.map((s) => s.setType), [
        SetType.warmup,
        SetType.drop,
      ]);
    });

    test('an older server that omits or garbles them yields normal sets', () {
      final page = remote.historyPageFromJson(
        pageJson({
          'exerciseName': 'Bench',
          'exerciseMuscles': ['chest'],
          'exerciseCategory': 'compound',
          'sets': [
            {'plannedReps': ''},
            {'setType': 'superset', 'plannedReps': ''},
          ],
        }),
      );

      final exercise = page.items.single.session.exercises.single;
      expect(exercise.note, isNull);
      expect(exercise.sets.map((s) => s.setType), [
        SetType.normal,
        SetType.normal,
      ]);
    });

    test('history detail JSON parses setType and note', () {
      final exercise = trainingExerciseDetailFromJson({
        'exerciseId': 'e',
        'exerciseName': 'Bench',
        'muscles': ['chest'],
        'note': 'Ławka niżej',
        'sets': [
          {'setIndex': 0, 'setType': 'failure', 'completed': true},
          {'setIndex': 1, 'completed': true},
        ],
      });

      expect(exercise.note, 'Ławka niżej');
      expect(exercise.sets.map((s) => s.setType), [
        SetType.failure,
        SetType.normal,
      ]);
    });

    test('the offline detail cache keeps set types and the note', () {
      final source = TrainingHistoryRemoteDataSource(_NoNetworkApi());
      final detail = source.detailFromCachedJson({
        'id': 'srv-1',
        'startedAt': '2026-09-01T10:00:00.000Z',
        'status': 'completed',
        'exercises': [
          {
            'exerciseId': 'e',
            'exerciseName': 'Bench',
            'muscles': ['chest'],
            'note': 'z pauzą',
            'sets': [
              {'setIndex': 0, 'setType': 'warmup', 'completed': true},
            ],
          },
        ],
      });

      final roundTripped = source.detailFromCachedJson(
        source.detailToCachedJson(detail),
      );
      final exercise = roundTripped.exercises.single;
      expect(exercise.note, 'z pauzą');
      expect(exercise.sets.single.setType, SetType.warmup);
    });
  });

  group('LocalPreviousPerformanceRepository', () {
    late ExerciseDatabase db;
    late LocalPreviousPerformanceRepository repository;

    setUp(() {
      db = ExerciseDatabase('previous.db', directoryOverride: dir.path);
      repository = LocalPreviousPerformanceRepository(db);
    });

    tearDown(() => db.close());

    Future<void> save(TrainingSession session, {String? pendingOp}) {
      return db.run(
        (database) => TrainingSessionLocalMapper.upsert(
          database,
          session,
          pendingOp: pendingOp,
        ),
      );
    }

    test('returns the completed sets of the latest finished workout', () async {
      await save(
        _session('old', DateTime.utc(2026, 8, 1), [
          _exercise('e-old', [_set('o1', '90', '5')]),
        ]),
      );
      await save(
        _session('latest', DateTime.utc(2026, 9, 1), [
          _exercise('e-latest', [
            _set('l1', '60', '10', type: SetType.warmup),
            _set('l2', '105', '5'),
            _set('l3', '105', '3', completed: false),
            _set('l4', '100', '6', type: SetType.drop),
          ]),
        ]),
      );

      final sets = await repository.lastCompletedSets(
        exerciseId: 'bench',
        exerciseName: 'Bench',
      );

      expect(sets!.map((s) => s.id), ['l1', 'l2', 'l4']);
      expect(sets.map((s) => s.setType), [
        SetType.warmup,
        SetType.normal,
        SetType.drop,
      ]);
    });

    test('ignores active, deleted-pending and warm-up-only workouts', () async {
      await save(
        _session('good', DateTime.utc(2026, 8, 1), [
          _exercise('e-good', [_set('g1', '90', '5')]),
        ]),
      );
      await save(
        _session('active', DateTime.utc(2026, 9, 5), [
          _exercise('e-active', [_set('a1', '200', '1')]),
        ], status: TrainingSessionStatus.active),
      );
      await save(
        _session('gone', DateTime.utc(2026, 9, 4), [
          _exercise('e-gone', [_set('x1', '300', '1')]),
        ]),
        pendingOp: 'delete',
      );
      await save(
        _session('warm', DateTime.utc(2026, 9, 3), [
          _exercise('e-warm', [_set('w1', '40', '10', type: SetType.warmup)]),
        ]),
      );

      final sets = await repository.lastCompletedSets(
        exerciseId: 'bench',
        exerciseName: 'Bench',
      );

      expect(sets!.single.id, 'g1');
    });

    test(
      'falls back to the name (case-insensitive) when there is no id',
      () async {
        await save(
          _session('s', DateTime.utc(2026, 9, 1), [
            _exercise(
              'e',
              [_set('s1', '100', '5')],
              exerciseId: 'server-side-id',
              name: 'Wyciskanie sztangi',
            ),
          ]),
        );

        final byName = await repository.lastCompletedSets(
          exerciseId: '',
          exerciseName: 'wyciskanie SZTANGI',
        );
        final other = await repository.lastCompletedSets(
          exerciseId: 'different',
          exerciseName: 'Przysiad',
        );

        expect(byName!.single.id, 's1');
        expect(other, isNull);
      },
    );

    test('returns null when the exercise was never performed', () async {
      expect(
        await repository.lastCompletedSets(
          exerciseId: 'bench',
          exerciseName: 'Bench',
        ),
        isNull,
      );
    });
  });
}
