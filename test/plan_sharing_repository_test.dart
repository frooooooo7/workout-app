import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/data/offline_first_training_plan_repository.dart';
import 'package:gym/features/training/data/plan_sharing_repository.dart';
import 'package:gym/features/training/data/sync/training_plan_sync_engine.dart';
import 'package:gym/features/training/data/training_plan_remote_data_source.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dir;
  late ExerciseDatabase db;
  late _FakeApi api;
  late TrainingPlanSyncEngine sync;
  late PlanSharingRepository sharing;
  late OfflineFirstTrainingPlanRepository plans;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('gym_plan_sharing');
    db = ExerciseDatabase('plans.db', directoryOverride: dir.path);
    api = _FakeApi();
    final remote = TrainingPlanRemoteDataSource(api);
    sync = TrainingPlanSyncEngine(remote: remote, localDb: db);
    sharing = PlanSharingRepository(remote: remote, syncEngine: sync);
    plans = OfflineFirstTrainingPlanRepository(
      localDb: db,
      syncEngine: TrainingPlanSyncEngine(remote: remote, localDb: db)..stop(),
    );
  });

  tearDown(() async {
    sync.stop();
    await db.close();
    await dir.delete(recursive: true);
  });

  test('a copied plan is stored under its client id, already synced', () async {
    final outcome = await sharing.copyPlan(_sourcePlanId);

    expect(api.posts.single.path, '/training-plans/$_sourcePlanId/copy');
    final clientId = api.posts.single.body['clientId'] as String;
    expect(outcome.plan.id, clientId);
    expect(outcome.skippedExercises, 1);
    expect(sharing.recentlyCopiedPlanId.value, clientId);
    expect(sharing.copyNotice.value?.plan.id, clientId);

    final stored = await plans.getById(clientId);
    expect(stored, isNotNull);
    expect(stored!.name, 'Pull B');
    expect(stored.selectedDays, isEmpty);
    expect(stored.isPublic, isFalse);
    expect(
      stored.copiedFrom,
      const PlanAuthor(userId: _authorId, handle: 'anna'),
    );
    expect(stored.exercises.single.sets.single.weight, isNull);
    expect(stored.exercises.single.restSeconds, 180);

    await db.run((database) async {
      final row = (await database.query(
        ExerciseDatabase.tableTrainingPlans,
      )).single;
      expect(row['server_id'], _copyPlanId);
      expect(row['pending_op'], isNull);
    });
  });

  test('copying from a post calls the post endpoint', () async {
    await sharing.copyFromPost('session-1');

    expect(api.posts.single.path, '/posts/session-1/copy-plan');
  });

  test('a pull fetched before the copy does not drop the copy', () async {
    final list = Completer<List<dynamic>>();
    api.plansList = list.future;

    final pull = sync.pull();
    final outcome = await sharing.copyPlan(_sourcePlanId);
    list.complete(const []);
    await pull;

    expect(await plans.getById(outcome.plan.id), isNotNull);
  });

  test('a failed copy stores nothing and leaves the badge alone', () async {
    api.failPosts = true;

    await expectLater(
      sharing.copyPlan(_sourcePlanId),
      throwsA(isA<ApiException>()),
    );

    expect(await plans.getAll(), isEmpty);
    expect(sharing.recentlyCopiedPlanId.value, isNull);
    expect(sharing.copyNotice.value, isNull);
  });

  test(
    'visibility, author and copy count survive the local round trip',
    () async {
      final exercise = Exercise(
        id: 'local-ex',
        name: 'Wiosłowanie',
        muscles: const [MuscleGroup.back],
        category: ExerciseCategory.compound,
      );
      final created = await plans.create(
        CustomTrainingPlan(
          name: 'Pull',
          selectedDays: const [2],
          isPublic: true,
          copyCount: 4,
          copiedFrom: const PlanAuthor(userId: _authorId, handle: 'anna'),
          exercises: [
            PlanExercise(
              exercise: exercise,
              sets: [ExerciseSet(reps: '8')],
            ),
          ],
        ),
      );

      final loaded = (await plans.getById(created.id))!;
      expect(loaded.isPublic, isTrue);
      expect(loaded.copyCount, 4);
      expect(loaded.copiedFrom?.handle, 'anna');
    },
  );

  test('the request body carries the visibility', () {
    final remote = TrainingPlanRemoteDataSource(api);
    final body = remote.toBody(
      CustomTrainingPlan(name: 'Pull', selectedDays: const [], isPublic: true),
      exerciseServerIdsByLocalId: const {},
    );
    expect(body['isPublic'], isTrue);
  });

  test('public plans of a user come from the profile endpoint', () async {
    api.plansList = Future.value([_planJson(id: _sourcePlanId, copies: 12)]);

    final result = await sharing.publicPlans(_authorId);

    expect(api.gets.single, '/users/$_authorId/plans');
    expect(result.single.copyCount, 12);
    expect(result.single.copiedFrom, isNull);
  });
}

const _authorId = '44444444-4444-4444-8444-444444444444';
const _sourcePlanId = '55555555-5555-4555-8555-555555555555';
const _copyPlanId = '66666666-6666-4666-8666-666666666666';

Map<String, dynamic> _planJson({
  required String id,
  String? clientId,
  int copies = 0,
  Map<String, dynamic>? copiedFrom,
}) => {
  'id': id,
  'clientId': clientId,
  'name': 'Pull B',
  'note': null,
  'selectedDays': <int>[],
  'defaultRestSeconds': 120,
  'isPublic': false,
  'copyCount': copies,
  'copiedFrom': copiedFrom,
  'exercises': [
    {
      'id': 'pe-1',
      'clientId': null,
      'restSeconds': 180,
      'supersetGroup': null,
      'exercise': {
        'id': '77777777-7777-4777-8777-777777777777',
        'name': 'Martwy ciąg',
        'muscles': ['back'],
        'category': 'compound',
        'isMine': false,
      },
      'sets': [
        {'id': 'set-1', 'weight': null, 'reps': '5'},
      ],
    },
  ],
};

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://127.0.0.1:9');

  final posts = <({String path, Map<String, dynamic> body})>[];
  final gets = <String>[];
  Future<List<dynamic>> plansList = Future.value(const []);
  bool failPosts = false;

  @override
  Future<dynamic> get(String path, {bool auth = false}) {
    gets.add(path);
    return plansList;
  }

  @override
  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    posts.add((path: path, body: body));
    if (failPosts) throw const ApiException('network_error');
    return {
      ..._planJson(
        id: _copyPlanId,
        clientId: body['clientId'] as String,
        copiedFrom: {
          'planId': _sourcePlanId,
          'userId': _authorId,
          'handle': 'anna',
        },
      ),
      'skippedExercises': 1,
    };
  }
}
