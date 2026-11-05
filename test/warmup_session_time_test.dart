import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/data/offline_first_training_session_repository.dart';
import 'package:gym/features/training/data/sync/training_session_sync_engine.dart';
import 'package:gym/features/training/data/training_session_local_mapper.dart';
import 'package:gym/features/training/data/training_session_remote_data_source.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:gym/features/training/domain/models/warmup.dart';
import 'package:gym/features/training/domain/services/training_session_detail_mapper.dart';
import 'package:gym/features/training/domain/services/workout_edit.dart';
import 'package:gym/features/training/presentation/bloc/training_session_cubit.dart';
import 'package:gym/features/training/presentation/utils/start_workout.dart';
import 'package:gym/features/training/presentation/widgets/session_details/session_summary_header.dart';
import 'package:gym/features/training/presentation/widgets/session_details/warmup_time_note.dart';
import 'package:gym/features/training/presentation/widgets/workout_summary/workout_summary_stats_card.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('warmupSecondsToSave', () {
    test('under a minute is not saved', () {
      expect(warmupSecondsToSave(Duration.zero), isNull);
      expect(warmupSecondsToSave(const Duration(seconds: 59)), isNull);
    });

    test('a minute and more is saved as seconds, capped at two hours', () {
      expect(warmupSecondsToSave(const Duration(seconds: 60)), 60);
      expect(warmupSecondsToSave(const Duration(minutes: 8, seconds: 24)), 504);
      expect(warmupSecondsToSave(const Duration(hours: 5)), 7200);
    });
  });

  test('WarmupTimeNote formats minutes and seconds', () {
    expect(WarmupTimeNote.format(504), '8:24');
    expect(WarmupTimeNote.format(65), '1:05');
    expect(WarmupTimeNote.format(3600), '60:00');
  });

  group('local database', () {
    late Directory dir;
    late ExerciseDatabase db;
    late OfflineFirstTrainingSessionRepository repo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('gym_warmup_time');
      db = ExerciseDatabase('warmup.db', directoryOverride: dir.path);
      final remote = TrainingSessionRemoteDataSource(
        ApiClient(baseUrl: 'http://127.0.0.1:9', getToken: () async => ''),
      );
      repo = OfflineFirstTrainingSessionRepository(
        localDb: db,
        syncEngine: TrainingSessionSyncEngine(remote: remote, localDb: db)
          ..stop(),
        remote: remote,
      );
    });

    tearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });

    test('attachWarmupSeconds stores the time and finish keeps it', () async {
      final cubit = TrainingSessionCubit(repo);
      addTearDown(cubit.close);
      final started = await cubit.startFromPlan(_plan());
      final withWarmup = await attachWarmupSeconds(cubit, started!, 504);
      expect(withWarmup.warmupSeconds, 504);

      final finished = await repo.finish(started.id);
      expect(finished.warmupSeconds, 504);
      expect((await repo.getById(started.id))?.warmupSeconds, 504);
      await db.run((db) async {
        final row = (await db.query(
          ExerciseDatabase.tableTrainingSessions,
        )).single;
        expect(row['warmup_seconds'], 504);
      });
      expect(trainingSessionDetailFromSession(finished).warmupSeconds, 504);
    });

    test('without a measured time nothing is written', () async {
      final cubit = TrainingSessionCubit(repo);
      addTearDown(cubit.close);
      final started = await cubit.startFromPlan(_plan());
      final same = await attachWarmupSeconds(cubit, started!, null);
      expect(same.warmupSeconds, isNull);
      expect((await repo.getById(started.id))?.warmupSeconds, isNull);
    });

    test('a server copy without the field keeps the local time', () async {
      final cubit = TrainingSessionCubit(repo);
      addTearDown(cubit.close);
      final started = await cubit.startFromPlan(_plan());
      await attachWarmupSeconds(cubit, started!, 300);

      // Starszy backend nie zna pola i odsyła sesję bez niego.
      await db.run((db) async {
        final local = (await repo.getById(started.id))!;
        await TrainingSessionLocalMapper.upsert(
          db,
          TrainingSession(
            id: local.id,
            serverId: 'srv-1',
            planName: local.planName,
            startedAt: local.startedAt,
            exercises: local.exercises,
          ),
          fromServer: true,
        );
      });
      expect((await repo.getById(started.id))?.warmupSeconds, 300);
    });

    test('editing a finished workout keeps the warm-up time', () async {
      final cubit = TrainingSessionCubit(repo);
      addTearDown(cubit.close);
      final started = await cubit.startFromPlan(_plan());
      await attachWarmupSeconds(cubit, started!, 504);
      final finished = await repo.finish(started.id);

      final edited = applyWorkoutEdit(
        finished,
        WorkoutEditDraft.fromSession(finished),
      );
      expect(edited.warmupSeconds, 504);
    });
  });

  group('shown on the session screens', () {
    Future<void> pump(WidgetTester tester, Widget child) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      );
    }

    final noteFinder = find.byKey(const ValueKey('warmup-time-note'));

    for (final withWarmup in [true, false]) {
      testWidgets(
        'details header ${withWarmup ? 'shows' : 'hides'} the warm-up',
        (tester) async {
          final detail = trainingSessionDetailFromSession(
            _finished(withWarmup ? 504 : null),
          );
          await pump(tester, SessionSummaryHeader(detail: detail));

          expect(noteFinder, withWarmup ? findsOneWidget : findsNothing);
          if (withWarmup) {
            expect(find.textContaining('8:24'), findsOneWidget);
            expect(find.textContaining('poza czasem treningu'), findsOneWidget);
          }
        },
      );

      testWidgets(
        'summary card ${withWarmup ? 'shows' : 'hides'} the warm-up',
        (tester) async {
          final detail = trainingSessionDetailFromSession(
            _finished(withWarmup ? 504 : null),
          );
          await pump(tester, WorkoutSummaryStatsCard(detail: detail));

          expect(noteFinder, withWarmup ? findsOneWidget : findsNothing);
        },
      );
    }
  });

  test('database v22 gets the warmup_seconds column on open', () async {
    final dir = await Directory.systemTemp.createTemp('gym_v23_mig');
    final legacy = await openDatabase(
      '${dir.path}/v22.db',
      version: 22,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE ${ExerciseDatabase.tableTrainingSessions} '
          '(local_id TEXT PRIMARY KEY NOT NULL, plan_name TEXT NOT NULL)',
        );
      },
    );
    await legacy.insert(ExerciseDatabase.tableTrainingSessions, {
      'local_id': 's1',
      'plan_name': 'Push',
    });
    await legacy.close();

    final edb = ExerciseDatabase('v22.db', directoryOverride: dir.path);
    await edb.run((db) async {
      final row = (await db.query(
        ExerciseDatabase.tableTrainingSessions,
      )).single;
      expect(row.containsKey('warmup_seconds'), isTrue);
      expect(row['warmup_seconds'], isNull);
      expect(row['plan_name'], 'Push');
    });
    await edb.close();
    await dir.delete(recursive: true);
  });

  group('API', () {
    late HttpServer server;
    final bodies = <Map<String, dynamic>>[];
    Map<String, dynamic> response = {};

    // flutter_test podmienia HttpClient na taki, który zawsze zwraca 400.
    setUpAll(() => HttpOverrides.global = null);

    setUp(() async {
      bodies.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final text = await utf8.decoder.bind(request).join();
        bodies.add(jsonDecode(text) as Map<String, dynamic>);
        request.response
          ..statusCode = 201
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(response));
        await request.response.close();
      });
    });

    tearDown(() => server.close(force: true));

    TrainingSessionRemoteDataSource remote() => TrainingSessionRemoteDataSource(
      ApiClient(
        baseUrl: 'http://127.0.0.1:${server.port}',
        getToken: () async => 't',
      ),
    );

    Map<String, dynamic> serverJson({int? warmup}) => {
      'id': 'srv-1',
      'clientId': 'loc-1',
      'planName': 'Push',
      'status': 'completed',
      'startedAt': '2026-11-05T18:00:00.000Z',
      'finishedAt': '2026-11-05T19:00:00.000Z',
      'exercises': <dynamic>[],
      'warmupSeconds': ?warmup,
    };

    TrainingSession session({int? warmup}) => TrainingSession(
      id: 'loc-1',
      planName: 'Push',
      startedAt: DateTime.utc(2026, 11, 5, 18),
      exercises: const [],
      warmupSeconds: warmup,
    );

    test('sends warmupSeconds and reads it back', () async {
      response = serverJson(warmup: 504);
      final created = await remote().create(
        session(warmup: 504),
        exerciseServerIdsByLocalId: const {},
      );
      expect(bodies.single['warmupSeconds'], 504);
      expect(created.warmupSeconds, 504);
    });

    test(
      'omits warmupSeconds when unknown so the server keeps its value',
      () async {
        response = serverJson();
        final created = await remote().create(
          session(),
          exerciseServerIdsByLocalId: const {},
        );
        expect(bodies.single.containsKey('warmupSeconds'), isFalse);
        expect(created.warmupSeconds, isNull);
      },
    );
  });
}

TrainingSession _finished(int? warmupSeconds) => TrainingSession(
  id: 'loc-1',
  planName: 'Push',
  status: TrainingSessionStatus.completed,
  startedAt: DateTime.utc(2026, 11, 5, 18),
  finishedAt: DateTime.utc(2026, 11, 5, 19),
  exercises: const [],
  warmupSeconds: warmupSeconds,
);

CustomTrainingPlan _plan() {
  final exercise = Exercise(
    id: 'ex-1',
    name: 'Bench',
    muscles: const [MuscleGroup.chest],
    category: ExerciseCategory.compound,
    isMine: true,
    createdAt: DateTime.utc(2026),
  );
  return CustomTrainingPlan(
    name: 'FBW',
    exercises: [
      PlanExercise(
        exercise: exercise,
        sets: [ExerciseSet(weight: '60', reps: '8')],
      ),
    ],
  );
}
