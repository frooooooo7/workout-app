import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/training/data/offline_first_training_session_repository.dart';
import 'package:gym/features/training/data/pending_post_photo_store.dart';
import 'package:gym/features/training/data/sync/training_session_sync_engine.dart';
import 'package:gym/features/training/data/training_session_remote_data_source.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/post_draft.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
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
    dir = await Directory.systemTemp.createTemp('gym_post_photo');
    db = ExerciseDatabase('posts.db', directoryOverride: dir.path);
  });

  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  OfflineFirstTrainingSessionRepository repoWith(_SpyRemote remote) {
    return OfflineFirstTrainingSessionRepository(
      localDb: db,
      syncEngine: TrainingSessionSyncEngine(remote: remote, localDb: db)
        ..stop(),
      remote: remote,
    );
  }

  Future<TrainingSession> finishedSession(
    OfflineFirstTrainingSessionRepository repo,
  ) async {
    final session = await repo.startFromPlan(_plan());
    return repo.finish(session.id);
  }

  Future<List<int>?> pendingBytes(
    OfflineFirstTrainingSessionRepository repo,
    String id,
  ) async {
    final change = await repo.pendingPostPhoto(id);
    return change is SetPostPhoto ? change.photo.bytes : null;
  }

  final photo = PickedPostPhoto(
    bytes: Uint8List.fromList([1, 2, 3, 4]),
    filename: 'gym.jpg',
  );

  test('sharePost offline stores title, body and queues the photo', () async {
    final remote = _SpyRemote();
    final repo = repoWith(remote);
    final session = await finishedSession(repo);

    final shared = await repo.sharePost(
      session.id,
      PostDraft(
        title: '  Nowy rekord ',
        body: 'W końcu 120 kg',
        photo: SetPostPhoto(photo),
      ),
    );

    expect(shared.sharedToProfile, isTrue);
    expect(shared.postTitle, 'Nowy rekord');
    expect(shared.note, 'W końcu 120 kg');
    expect(await pendingBytes(repo, session.id), [1, 2, 3, 4]);
    expect(remote.log, isEmpty);
    await db.run((db) async {
      final row = (await db.query(
        ExerciseDatabase.tableTrainingSessions,
      )).single;
      expect(row['post_title'], 'Nowy rekord');
      expect(row['shared_to_profile'], 1);
    });
    expect((await db.countSyncBacklog()).pending, 2);
  });

  test('blank fields clear the title and the note', () async {
    final repo = repoWith(_SpyRemote());
    final session = await finishedSession(repo);
    await repo.sharePost(
      session.id,
      const PostDraft(title: 'Stary', body: 'Stary opis'),
    );

    final shared = await repo.sharePost(
      session.id,
      const PostDraft(title: ' ', body: ''),
    );

    expect(shared.postTitle, isNull);
    expect(shared.note, isNull);
  });

  test('flush sends the session first, then uploads the photo', () async {
    final remote = _SpyRemote();
    final repo = repoWith(remote);
    final session = await finishedSession(repo);
    await repo.sharePost(
      session.id,
      PostDraft(title: 'Tytuł', photo: SetPostPhoto(photo)),
    );

    await TrainingSessionSyncEngine(remote: remote, localDb: db).flush();

    expect(remote.log, ['create', 'upload:$_serverId:gym.jpg']);
    expect(remote.createdSessions.single.postTitle, 'Tytuł');
    expect(await repo.pendingPostPhoto(session.id), isA<KeepPostPhoto>());
    final stored = await repo.getById(session.id);
    expect(stored?.postPhotoUrl, '/uploads/post-photos/p.webp');
    expect((await db.countSyncBacklog()).pending, 0);
  });

  test('a network failure keeps the photo in the queue', () async {
    final remote = _SpyRemote(failUpload: const ApiException('network_error'));
    final repo = repoWith(remote);
    final session = await finishedSession(repo);
    await repo.sharePost(session.id, PostDraft(photo: SetPostPhoto(photo)));

    await TrainingSessionSyncEngine(remote: remote, localDb: db).flush();

    expect(remote.log, ['create', 'upload:$_serverId:gym.jpg']);
    expect(await pendingBytes(repo, session.id), [1, 2, 3, 4]);
  });

  test('a session deleted on the server drops its queued photo', () async {
    final remote = _SpyRemote(
      failUpload: const ApiException('session_deleted', statusCode: 410),
    );
    final repo = repoWith(remote);
    final session = await finishedSession(repo);
    await repo.sharePost(session.id, PostDraft(photo: SetPostPhoto(photo)));

    await TrainingSessionSyncEngine(remote: remote, localDb: db).flush();

    expect(await repo.pendingPostPhoto(session.id), isA<KeepPostPhoto>());
    expect((await db.countSyncBacklog()).pending, 0);
  });

  test('removing the photo calls DELETE after the session is synced', () async {
    final remote = _SpyRemote();
    final repo = repoWith(remote);
    final session = await finishedSession(repo);
    await repo.sharePost(session.id, PostDraft(photo: SetPostPhoto(photo)));
    final engine = TrainingSessionSyncEngine(remote: remote, localDb: db);
    await engine.flush();

    await repo.sharePost(session.id, const PostDraft(photo: RemovePostPhoto()));
    await engine.flush();

    expect(remote.log.last, 'delete-photo:$_serverId');
    expect((await repo.getById(session.id))?.postPhotoUrl, isNull);
  });

  test('deleting the session drops its queued photo', () async {
    final repo = repoWith(_SpyRemote());
    final session = await finishedSession(repo);
    await repo.sharePost(session.id, PostDraft(photo: SetPostPhoto(photo)));

    await repo.delete(session.id);

    await db.run((db) async {
      final rows = await db.query(ExerciseDatabase.tablePendingPostPhotos);
      expect(rows, isEmpty);
    });
  });

  test(
    'removing the photo hides it at once and survives a server pull',
    () async {
      final remote = _SpyRemote();
      final repo = repoWith(remote);
      final session = await finishedSession(repo);
      await repo.sharePost(session.id, PostDraft(photo: SetPostPhoto(photo)));
      final engine = TrainingSessionSyncEngine(remote: remote, localDb: db);
      await engine.flush();
      expect(
        (await repo.getById(session.id))?.postPhotoUrl,
        '/uploads/post-photos/p.webp',
      );

      remote.failDelete = const ApiException('network_error');
      final updated = await repo.sharePost(
        session.id,
        const PostDraft(photo: RemovePostPhoto()),
      );
      expect(updated.postPhotoUrl, isNull);
      expect(await repo.pendingPostPhoto(session.id), isA<RemovePostPhoto>());

      // PUT sesji wraca z serwera ze starym adresem — nie może go przywrócić.
      await engine.flush();
      expect((await repo.getById(session.id))?.postPhotoUrl, isNull);
    },
  );

  test(
    'a rejected photo is counted as failed and retried after clearing',
    () async {
      final remote = _SpyRemote(
        failUpload: const ApiException('invalid_file', statusCode: 400),
      );
      final repo = repoWith(remote);
      final session = await finishedSession(repo);
      await repo.sharePost(session.id, PostDraft(photo: SetPostPhoto(photo)));

      await TrainingSessionSyncEngine(remote: remote, localDb: db).flush();
      var backlog = await db.countSyncBacklog();
      expect(backlog.failed, 1);
      expect(backlog.pending, 0);

      await db.clearSyncErrors();
      backlog = await db.countSyncBacklog();
      expect(backlog.pending, 1);
      expect(backlog.failed, 0);
    },
  );

  test('a rejection of an older upload does not mark a newer photo', () async {
    final repo = repoWith(_SpyRemote());
    final session = await finishedSession(repo);
    await repo.sharePost(session.id, PostDraft(photo: SetPostPhoto(photo)));
    final old = await db.run(
      (db) async => (await PendingPostPhotoStore.all(db)).single,
    );
    expect(old.bytes, isNull, reason: 'all() reads metadata only');

    await repo.sharePost(
      session.id,
      PostDraft(
        photo: SetPostPhoto(
          PickedPostPhoto(bytes: Uint8List.fromList([9]), filename: 'b.png'),
        ),
      ),
    );
    await db.run(
      (db) => PendingPostPhotoStore.markRejected(
        db,
        old.sessionLocalId,
        'invalid_file',
        onlyVersion: old.version,
      ),
    );

    expect((await db.countSyncBacklog()).failed, 0);
    expect(await pendingBytes(repo, session.id), [9]);
  });

  test('toBody sends postTitle with the session', () {
    final remote = _SpyRemote();
    final body = remote.toBody(
      TrainingSession(planName: 'Push', postTitle: 'Mój post', exercises: []),
      exerciseServerIdsByLocalId: const {},
    );
    expect(body['postTitle'], 'Mój post');
  });
}

const _exerciseId = '11111111-1111-4111-8111-111111111111';
const _serverId = '33333333-3333-4333-8333-333333333333';

CustomTrainingPlan _plan() {
  final exercise = Exercise(
    id: _exerciseId,
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

class _SpyRemote extends TrainingSessionRemoteDataSource {
  _SpyRemote({this.failUpload})
    : super(ApiClient(baseUrl: 'http://127.0.0.1:9', getToken: () async => ''));

  final ApiException? failUpload;
  ApiException? failDelete;
  final List<String> log = [];
  final List<TrainingSession> createdSessions = [];
  String? _photoUrl;

  @override
  Future<TrainingSession> create(
    TrainingSession session, {
    required Map<String, String?> exerciseServerIdsByLocalId,
  }) async {
    log.add('create');
    createdSessions.add(session);
    return session.copyWith(serverId: _serverId);
  }

  @override
  Future<TrainingSession> update(
    String serverId,
    TrainingSession session, {
    required Map<String, String?> exerciseServerIdsByLocalId,
  }) async {
    log.add('update:$serverId');
    return session.copyWith(
      serverId: serverId,
      postPhotoUrl: _photoUrl,
      clearPostPhotoUrl: _photoUrl == null,
    );
  }

  @override
  Future<TrainingSession> uploadPostPhoto(
    String serverId,
    Uint8List bytes,
    String filename,
  ) async {
    log.add('upload:$serverId:$filename');
    final failure = failUpload;
    if (failure != null) throw failure;
    _photoUrl = '/uploads/post-photos/p.webp';
    return TrainingSession(
      id: serverId,
      serverId: serverId,
      planName: 'FBW',
      exercises: const [],
      postPhotoUrl: _photoUrl,
    );
  }

  @override
  Future<TrainingSession> deletePostPhoto(String serverId) async {
    log.add('delete-photo:$serverId');
    final failure = failDelete;
    if (failure != null) throw failure;
    _photoUrl = null;
    return TrainingSession(
      id: serverId,
      serverId: serverId,
      planName: 'FBW',
      exercises: const [],
    );
  }
}
