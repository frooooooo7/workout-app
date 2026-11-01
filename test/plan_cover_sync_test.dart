import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/library/data/exercise_dto.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/data/offline_first_training_plan_repository.dart';
import 'package:gym/features/training/data/sync/training_plan_sync_engine.dart';
import 'package:gym/features/training/data/training_plan_remote_data_source.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/post_draft.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _exerciseLocalId = '11111111-1111-4111-8111-111111111111';
const _exerciseServerId = '22222222-2222-4222-8222-222222222222';
const _planServerId = '33333333-3333-4333-8333-333333333333';
const _coverUrl = '/uploads/plan-covers/c.webp';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory dir;
  late ExerciseDatabase db;
  late Exercise exercise;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('gym_plan_cover');
    db = ExerciseDatabase('covers.db', directoryOverride: dir.path);
    exercise = Exercise(
      id: _exerciseLocalId,
      name: 'Bench',
      muscles: const [MuscleGroup.chest],
      category: ExerciseCategory.compound,
      isMine: true,
      createdAt: DateTime.utc(2024),
    );
    await db.run(
      (database) => database.insert(
        ExerciseDatabase.tableExercises,
        ExerciseDto.fromDomain(
          exercise,
          serverIdOverride: _exerciseServerId,
        ).toMap(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  OfflineFirstTrainingPlanRepository repoWith(_SpyRemote remote) {
    return OfflineFirstTrainingPlanRepository(
      localDb: db,
      syncEngine: TrainingPlanSyncEngine(remote: remote, localDb: db)..stop(),
    );
  }

  Future<void> flush(_SpyRemote remote) =>
      TrainingPlanSyncEngine(remote: remote, localDb: db).flush();

  CustomTrainingPlan plan(String name, {int? sortOrder}) => CustomTrainingPlan(
    name: name,
    sortOrder: sortOrder,
    exercises: [
      PlanExercise(
        exercise: exercise,
        sets: [ExerciseSet(weight: '60', reps: '8')],
      ),
    ],
  );

  final photo = PickedPostPhoto(
    bytes: Uint8List.fromList([1, 2, 3, 4]),
    filename: 'cover.jpg',
  );

  test(
    'a cover chosen offline shows up at once and waits in the queue',
    () async {
      final remote = _SpyRemote();
      final repo = repoWith(remote);

      final created = await repo.create(
        plan('Push'),
        cover: SetPostPhoto(photo),
      );

      expect(created.coverBytes, [1, 2, 3, 4]);
      final listed = (await repo.getAll()).single;
      expect(listed.coverBytes, [1, 2, 3, 4]);
      expect(listed.coverUrl, isNull);
      expect(listed.hasCover, isTrue);
      expect(remote.log, isEmpty);
      // Plan czeka na wysyłkę, okładka także.
      expect((await db.countSyncBacklog()).pending, 2);
    },
  );

  test('flush sends the plan first, then uploads the cover', () async {
    final remote = _SpyRemote();
    final repo = repoWith(remote);
    await repo.create(plan('Push'), cover: SetPostPhoto(photo));

    await flush(remote);

    expect(remote.log, ['create', 'upload:$_planServerId:cover.jpg']);
    final stored = (await repo.getAll()).single;
    expect(stored.coverUrl, _coverUrl);
    expect(stored.coverBytes, isNull);
    expect((await db.countSyncBacklog()).pending, 0);
  });

  test('a network failure keeps the cover and shows it meanwhile', () async {
    final remote = _SpyRemote(failUpload: const ApiException('network_error'));
    final repo = repoWith(remote);
    await repo.create(plan('Push'), cover: SetPostPhoto(photo));

    await flush(remote);

    expect(remote.log, ['create', 'upload:$_planServerId:cover.jpg']);
    final stored = (await repo.getAll()).single;
    expect(stored.coverBytes, [1, 2, 3, 4]);
    expect((await db.countSyncBacklog()).pending, 1);

    // Następna próba po powrocie sieci.
    remote.failUpload = null;
    await flush(remote);
    expect((await repo.getAll()).single.coverUrl, _coverUrl);
    expect((await db.countSyncBacklog()).pending, 0);
  });

  test(
    'removing the cover hides it at once and deletes it on the server',
    () async {
      final remote = _SpyRemote();
      final repo = repoWith(remote);
      await repo.create(plan('Push'), cover: SetPostPhoto(photo));
      await flush(remote);
      remote.log.clear();

      final current = (await repo.getAll()).single;
      await repo.update(current, cover: const RemovePostPhoto());

      expect((await repo.getAll()).single.hasCover, isFalse);
      await flush(remote);

      expect(remote.log, [
        'update:$_planServerId',
        'deleteCover:$_planServerId',
      ]);
      final stored = (await repo.getAll()).single;
      expect(stored.coverUrl, isNull);
      expect((await db.countSyncBacklog()).pending, 0);
    },
  );

  test('keeping the cover does not touch the queue', () async {
    final remote = _SpyRemote();
    final repo = repoWith(remote);
    await repo.create(plan('Push'), cover: SetPostPhoto(photo));
    await flush(remote);
    remote.log.clear();

    final current = (await repo.getAll()).single;
    await repo.update(current.copyWith(name: 'Push A'));
    await flush(remote);

    expect(remote.log, ['update:$_planServerId']);
    expect((await repo.getAll()).single.coverUrl, _coverUrl);
  });

  test('deleting a plan that was never synced drops its cover', () async {
    final remote = _SpyRemote();
    final repo = repoWith(remote);
    final created = await repo.create(plan('Push'), cover: SetPostPhoto(photo));

    await repo.delete(created.id);

    expect((await db.countSyncBacklog()).pending, 0);
    await db.run((database) async {
      expect(
        await database.query(ExerciseDatabase.tablePendingPlanCovers),
        isEmpty,
      );
    });
  });

  test(
    'reorder saves the order, marks the plans and sends sortOrder',
    () async {
      final remote = _SpyRemote();
      final repo = repoWith(remote);
      final a = await repo.create(plan('A'));
      final b = await repo.create(plan('B'));
      final c = await repo.create(plan('C'));
      await flush(remote);
      remote.log.clear();
      remote.sentSortOrders.clear();

      await repo.reorder([c.id, a.id, b.id]);

      expect([for (final p in await repo.getAll()) p.name], ['C', 'A', 'B']);
      expect([for (final p in await repo.getAll()) p.sortOrder], [0, 1, 2]);

      await flush(remote);
      expect(remote.sentSortOrders.toSet(), {0, 1, 2});
      // Po wysyłce kolejność została taka sama.
      expect([for (final p in await repo.getAll()) p.name], ['C', 'A', 'B']);
    },
  );

  test('a plan that was never moved stays on top of the sorted ones', () async {
    final remote = _SpyRemote();
    final repo = repoWith(remote);
    final a = await repo.create(plan('A'));
    final b = await repo.create(plan('B'));
    await repo.reorder([b.id, a.id]);

    await repo.create(plan('Nowy'));

    expect([for (final p in await repo.getAll()) p.name], ['Nowy', 'B', 'A']);
  });

  test('the request body carries sortOrder only for moved plans', () {
    final remote = _SpyRemote();
    expect(
      remote.toBody(plan('A'), exerciseServerIdsByLocalId: const {}),
      isNot(contains('sortOrder')),
    );
    expect(
      remote.toBody(
        plan('A', sortOrder: 2),
        exerciseServerIdsByLocalId: const {},
      ),
      containsPair('sortOrder', 2),
    );
  });
}

class _SpyRemote extends TrainingPlanRemoteDataSource {
  _SpyRemote({this.failUpload})
    : super(ApiClient(baseUrl: 'http://127.0.0.1:9', getToken: () async => ''));

  ApiException? failUpload;
  final List<String> log = [];
  final List<int?> sentSortOrders = [];
  int _created = 0;

  @override
  Future<List<CustomTrainingPlan>> getAll() async => const [];

  @override
  Future<CustomTrainingPlan> create(
    CustomTrainingPlan plan, {
    required Map<String, String> exerciseServerIdsByLocalId,
  }) async {
    log.add('create');
    sentSortOrders.add(plan.sortOrder);
    // Pierwszy plan dostaje znane id, kolejne — własne (inaczej pull
    // uznałby je za duplikaty jednego planu).
    _created++;
    final id = _created == 1
        ? _planServerId
        : _planServerId.replaceRange(0, 1, 'abcdef'[_created]);
    return plan.copyWith(id: id);
  }

  @override
  Future<CustomTrainingPlan> update(
    String serverId,
    CustomTrainingPlan plan, {
    required Map<String, String> exerciseServerIdsByLocalId,
  }) async {
    log.add('update:$serverId');
    sentSortOrders.add(plan.sortOrder);
    return plan.copyWith(id: serverId);
  }

  @override
  Future<CustomTrainingPlan> uploadCover(
    String serverId,
    Uint8List bytes,
    String filename,
  ) async {
    log.add('upload:$serverId:$filename');
    final error = failUpload;
    if (error != null) throw error;
    return CustomTrainingPlan(id: serverId, name: 'x', coverUrl: _coverUrl);
  }

  @override
  Future<CustomTrainingPlan> deleteCover(String serverId) async {
    log.add('deleteCover:$serverId');
    return CustomTrainingPlan(id: serverId, name: 'x');
  }

  @override
  Future<void> delete(String serverId) async {
    log.add('delete:$serverId');
  }
}
