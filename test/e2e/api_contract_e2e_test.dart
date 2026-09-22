// Testy kontraktowe klienta z PRAWDZIWYM backendem (gym_backend).
//
// Używają prawdziwego ApiClient (`<origin>/api/v1`) oraz prawdziwych remote
// data sources / repozytoriów API — sprawdzają, że parsowanie w `lib/` zgadza
// się z odpowiedziami serwera. Bez `E2E_BASE_URL` są pomijane.
//
//   flutter test test/e2e --dart-define=E2E_BASE_URL=http://localhost:3102
//
// Scenariusz jest sekwencyjny (testy w grupie dzielą stan).
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_asset_uri.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/core/session/session_manager.dart';
import 'package:gym/features/account/data/account_remote_data_source.dart';
import 'package:gym/features/account/data/api_account_repository.dart';
import 'package:gym/features/auth/data/auth_repository.dart';
import 'package:gym/features/auth/domain/models/auth_models.dart';
import 'package:gym/features/feed/data/api_feed_repository.dart';
import 'package:gym/features/library/data/exercise_remote_data_source.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/profile/data/api_profile_repository.dart';
import 'package:gym/features/training/data/training_history_remote_data_source.dart';
import 'package:gym/features/training/data/training_plan_remote_data_source.dart';
import 'package:gym/features/training/data/training_session_remote_data_source.dart';
import 'package:gym/features/training/domain/models/custom_training_plan.dart';
import 'package:gym/features/training/domain/models/training_session.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'e2e_config.dart';

final _png1x1 = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _User {
  _User(this.label);

  final String label;
  final storage = MemoryTokenStorage();
  late final ApiClient api = e2eApiClient(storage);
  late AuthUser user;

  String get id => user.id;
  String get email => 'e2e.$label.$e2eRunId@example.com';
  String get firstName => 'E2e${label.toUpperCase()}$e2eRunId';
}

void main() {
  group('API v1 contract (real backend)', skip: e2eSkip, () {
    final alice = _User('a');
    final bob = _User('b');

    late Exercise customExercise;
    late Exercise systemExercise;
    late CustomTrainingPlan plan;
    late TrainingSession shared;
    late String commentToKeep;

    test('register two users and log in', () async {
      for (final u in [alice, bob]) {
        final result = await AuthRepository(u.api).register(
          email: u.email,
          password: e2ePassword,
          firstName: u.firstName,
          lastName: 'Kontrakt',
        );
        expect(result.token, isNotEmpty);
        expect(result.user.email, u.email);
        expect(result.user.firstName, u.firstName);
        u.user = result.user;
        u.storage.token = result.token;
      }
      // Kształt `GET /auth/me` jak w AppUserBootstrap.
      final me = AuthUser.fromJson(
        await alice.api.get('/auth/me', auth: true) as Map<String, dynamic>,
      );
      expect(me.id, alice.id);
      expect(me.email, alice.email);

      final login = await AuthRepository(
        alice.api,
      ).login(email: alice.email, password: e2ePassword);
      expect(login.user.id, alice.id);
      alice.storage.token = login.token;

      await expectLater(
        AuthRepository(
          alice.api,
        ).login(email: alice.email, password: 'Wrong1password'),
        throwsA(isApiError('invalid_credentials', status: 401)),
      );
    });

    test('exercises: create custom + list (paged getAll)', () async {
      final remote = ExerciseRemoteDataSource(alice.api);
      final clientId = const Uuid().v4();
      customExercise = await remote.create(
        name: 'E2E wyciskanie $e2eRunId',
        muscles: const [MuscleGroup.chest, MuscleGroup.triceps],
        category: ExerciseCategory.compound,
        description: 'kontrakt',
        clientId: clientId,
      );
      expect(customExercise.clientId, clientId);
      expect(customExercise.isMine, isTrue);
      expect(customExercise.muscles, [MuscleGroup.chest, MuscleGroup.triceps]);

      final all = await remote.getAll();
      final mine = all.where((e) => e.id == customExercise.id).single;
      expect(mine.clientId, clientId);
      expect(mine.category, ExerciseCategory.compound);
      systemExercise = all.firstWhere((e) => !e.isMine);
      expect(systemExercise.muscles, isNotEmpty);

      final searched = await remote.getAll(query: 'E2E wyciskanie $e2eRunId');
      expect(searched.map((e) => e.id), [customExercise.id]);

      final fav = await remote.toggleFavourite(customExercise.id);
      expect(fav, isTrue);
    });

    test('training plan: create + list', () async {
      final remote = TrainingPlanRemoteDataSource(alice.api);
      final local = CustomTrainingPlan(
        name: 'E2E Push $e2eRunId',
        note: 'plan',
        selectedDays: const [1, 4],
        exercises: [
          PlanExercise(
            exercise: customExercise,
            sets: [
              ExerciseSet(weight: '80', reps: '5'),
              ExerciseSet(weight: '85', reps: '3', rir: '1'),
            ],
          ),
        ],
      );
      plan = await remote.create(
        local,
        exerciseServerIdsByLocalId: {customExercise.id: customExercise.id},
      );
      expect(plan.clientId, local.id);
      expect(plan.selectedDays, [1, 4]);
      expect(plan.exercises.single.exercise.id, customExercise.id);
      expect(plan.exercises.single.sets.map((s) => s.weight), ['80', '85']);

      final plans = await remote.getAll();
      expect(plans.map((p) => p.id), contains(plan.id));
    });

    test('training session: create completed + share to profile', () async {
      final remote = TrainingSessionRemoteDataSource(alice.api);
      final started = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      final local = TrainingSession(
        planLocalId: plan.clientId,
        planServerId: plan.id,
        planName: plan.name,
        status: TrainingSessionStatus.completed,
        note: 'Dobra sesja',
        startedAt: started,
        finishedAt: started.add(const Duration(minutes: 45)),
        exercises: [
          TrainingSessionExercise(
            exerciseId: customExercise.clientId!,
            exerciseName: customExercise.name,
            exerciseMuscles: const ['chest', 'triceps'],
            exerciseCategory: 'compound',
            sets: [
              TrainingSessionSet(
                plannedWeight: '80',
                plannedReps: '5',
                actualWeight: '80',
                actualReps: '5',
                completed: true,
                completedAt: started.add(const Duration(minutes: 5)),
              ),
              TrainingSessionSet(
                plannedWeight: '85',
                plannedReps: '3',
                actualWeight: '90',
                actualReps: '3',
                completed: true,
                completedAt: started.add(const Duration(minutes: 10)),
              ),
            ],
          ),
          TrainingSessionExercise(
            exerciseId: systemExercise.id,
            exerciseName: systemExercise.name,
            exerciseMuscles: systemExercise.muscles.map((m) => m.name).toList(),
            exerciseCategory: systemExercise.category.name,
            sets: [
              TrainingSessionSet(
                plannedReps: '10',
                actualWeight: '20',
                actualReps: '10',
                completed: true,
                completedAt: started.add(const Duration(minutes: 20)),
              ),
              TrainingSessionSet(plannedReps: '10'),
            ],
          ),
        ],
      );

      final created = await remote.create(
        local,
        exerciseServerIdsByLocalId: {
          customExercise.clientId!: customExercise.id,
          systemExercise.id: systemExercise.id,
        },
      );
      expect(created.id, local.id, reason: 'id = clientId');
      expect(created.serverId, isNotNull);
      expect(created.status, TrainingSessionStatus.completed);
      expect(created.planServerId, plan.id);
      expect(created.planLocalId, plan.clientId);
      expect(created.sharedToProfile, isFalse);
      expect(created.exercises, hasLength(2));
      expect(created.exercises.first.id, local.exercises.first.id);
      expect(created.exercises.first.exerciseId, customExercise.clientId);
      expect(created.exercises.first.sets.map((s) => s.actualWeight), [
        '80',
        '90',
      ]);
      expect(created.exercises.last.sets.last.completed, isFalse);

      // Upsert po clientId — powtórny POST nie tworzy duplikatu.
      final again = await remote.create(
        local,
        exerciseServerIdsByLocalId: {
          customExercise.clientId!: customExercise.id,
          systemExercise.id: systemExercise.id,
        },
      );
      expect(again.serverId, created.serverId);

      shared = await remote.setSharedToProfile(created.serverId!, true);
      expect(shared.sharedToProfile, isTrue);
      expect(shared.serverId, created.serverId);
    });

    test('follow: bob follows alice', () async {
      final bobProfiles = ApiProfileRepository(bob.api);
      final result = await bobProfiles.follow(alice.id);
      expect(result.isFollowing, isTrue);
      expect(result.followersCount, 1);
      final idempotent = await bobProfiles.follow(alice.id);
      expect(idempotent.followersCount, 1);

      await expectLater(
        bobProfiles.follow(bob.id),
        throwsA(isApiError('cannot_follow_self', status: 400)),
      );

      final aliceProfile = await bobProfiles.getUserProfile(alice.id);
      expect(aliceProfile.id, alice.id);
      expect(aliceProfile.firstName, alice.firstName);
      expect(aliceProfile.handle, isNotEmpty);
      expect(aliceProfile.isFollowing, isTrue);
      expect(aliceProfile.isOwnProfile, isFalse);
      expect(aliceProfile.stats.followersCount, 1);

      final bobSeenByAlice = await ApiProfileRepository(
        alice.api,
      ).getUserProfile(bob.id);
      expect(bobSeenByAlice.isFollowedBy, isTrue);
      expect(bobSeenByAlice.isFollowing, isFalse);

      final following = await bobProfiles.getFollowing();
      expect(following.map((u) => u.id), [alice.id]);
      expect(following.single.isFollowing, isTrue);

      final followers = await ApiProfileRepository(alice.api).getFollowers();
      expect(followers.map((u) => u.id), [bob.id]);

      final aliceFollowers = await bobProfiles.getUserFollowers(alice.id);
      expect(aliceFollowers.map((u) => u.id), [bob.id]);
      final aliceFollowing = await bobProfiles.getUserFollowing(alice.id);
      expect(aliceFollowing, isEmpty);
    });

    test(
      'feed: page parsing (FeedPost incl. topExercises/bestSet/muscles)',
      () async {
        final page = await ApiFeedRepository(bob.api).getFeed(limit: 10);
        final post = page.items.singleWhere((p) => p.id == shared.serverId);
        expect(post.author.id, alice.id);
        expect(post.author.firstName, alice.firstName);
        expect(post.author.handle, isNotEmpty);
        expect(post.title, plan.name);
        expect(post.note, 'Dobra sesja');
        expect(post.isOwn, isFalse);
        expect(post.durationSec, 45 * 60);
        expect(post.finishedAt, isNotNull);
        expect(post.exercisesCount, 2);
        expect(post.completedSetsCount, 3);
        expect(post.totalVolumeKg, 80 * 5 + 90 * 3 + 20 * 10);
        expect(
          post.muscles,
          containsAll([MuscleGroup.chest, MuscleGroup.triceps]),
        );
        expect(post.topExercises, isNotEmpty);
        final top = post.topExercises.firstWhere(
          (e) => e.name == customExercise.name,
        );
        expect(top.completedSets, 2);
        expect(top.bestSet, isNotNull);
        expect(top.bestSet!.weightKg, 90);
        expect(top.bestSet!.reps, 3);
        expect(post.kudosCount, 0);
        expect(post.hasKudoed, isFalse);

        final own = await ApiFeedRepository(alice.api).getFeed();
        expect(
          own.items.singleWhere((p) => p.id == shared.serverId).isOwn,
          isTrue,
        );

        await expectLater(
          ApiFeedRepository(bob.api).getFeed(cursor: 'not-a-cursor'),
          throwsA(isApiError('invalid_cursor', status: 400)),
        );
      },
    );

    test('post details + exercises', () async {
      final detail = await ApiFeedRepository(bob.api).getPost(shared.serverId!);
      expect(detail.post.id, shared.serverId);
      expect(detail.exercises, hasLength(2));
      final bench = detail.exercises.first;
      expect(bench.exerciseName, customExercise.name);
      expect(
        bench.muscles,
        containsAll([MuscleGroup.chest, MuscleGroup.triceps]),
      );
      expect(bench.sets, hasLength(2));
      expect(bench.sets.first.setIndex, isNonNegative);
      expect(bench.sets.last.actual?.weightKg, 90);
      expect(bench.sets.last.actual?.reps, 3);
      expect(bench.sets.last.planned?.weightKg, 85);
      expect(bench.sets.last.completed, isTrue);
      expect(bench.sets.last.completedAt, isNotNull);
      expect(detail.exercises.last.sets.last.completed, isFalse);

      final asSession = detail.toSessionDetail();
      expect(asSession.exercises, hasLength(2));
    });

    test('kudos toggle', () async {
      final feed = ApiFeedRepository(bob.api);
      final given = await feed.giveKudos(shared.serverId!);
      expect(given.hasKudoed, isTrue);
      expect(given.kudosCount, 1);
      final again = await feed.giveKudos(shared.serverId!);
      expect(again.kudosCount, 1);

      await expectLater(
        ApiFeedRepository(alice.api).giveKudos(shared.serverId!),
        throwsA(isApiError('cannot_kudo_own_post', status: 400)),
      );

      final givers = await feed.getKudos(shared.serverId!);
      expect(givers.map((u) => u.id), [bob.id]);

      final page = await feed.getFeed();
      final post = page.items.singleWhere((p) => p.id == shared.serverId);
      expect(post.hasKudoed, isTrue);
      expect(post.kudosCount, 1);
      expect(post.recentKudos.map((a) => a.id), contains(bob.id));

      final removed = await feed.removeKudos(shared.serverId!);
      expect(removed.hasKudoed, isFalse);
      expect(removed.kudosCount, 0);

      final regiven = await feed.giveKudos(shared.serverId!);
      expect(regiven.kudosCount, 1);
    });

    test('comments add / list / delete', () async {
      final bobFeed = ApiFeedRepository(bob.api);
      final aliceFeed = ApiFeedRepository(alice.api);

      final first = await bobFeed.addComment(shared.serverId!, 'Mocno! 💪');
      expect(first.body, 'Mocno! 💪');
      expect(first.author.id, bob.id);
      expect(first.isOwn, isTrue);
      expect(first.canDelete, isTrue);

      final second = await bobFeed.addComment(shared.serverId!, 'Drugi');
      commentToKeep = second.id;

      final seenByAlice = await aliceFeed.getComments(shared.serverId!);
      expect(seenByAlice.items.map((c) => c.id), [first.id, second.id]);
      expect(seenByAlice.items.first.isOwn, isFalse);
      expect(
        seenByAlice.items.first.canDelete,
        isTrue,
        reason: 'post author may delete comments',
      );
      expect(seenByAlice.hasMore, isFalse);

      final paged = await bobFeed.getComments(shared.serverId!, limit: 1);
      expect(paged.items.single.id, first.id);
      expect(paged.hasMore, isTrue);
      final next = await bobFeed.getComments(
        shared.serverId!,
        limit: 1,
        cursor: paged.nextCursor,
      );
      expect(next.items.single.id, second.id);

      await expectLater(
        bobFeed.addComment(shared.serverId!, '   '),
        throwsA(isApiError('invalid_comment_body', status: 400)),
      );

      await aliceFeed.deleteComment(shared.serverId!, first.id);
      final after = await bobFeed.getComments(shared.serverId!);
      expect(after.items.map((c) => c.id), [commentToKeep]);

      final post = (await bobFeed.getFeed()).items.singleWhere(
        (p) => p.id == shared.serverId,
      );
      expect(post.commentCount, 1);
    });

    test('profile + activities with kudos counts', () async {
      final own = await ApiProfileRepository(alice.api).getOwnProfile();
      expect(own.id, alice.id);
      expect(own.isOwnProfile, isTrue);
      expect(own.stats.workoutsCount, greaterThanOrEqualTo(1));
      expect(own.stats.followersCount, 1);

      final updated = await ApiProfileRepository(
        alice.api,
      ).updateProfile(bio: 'Bio E2E');
      expect(updated.bio, 'Bio E2E');
      final cleared = await ApiProfileRepository(
        alice.api,
      ).updateProfile(bio: '');
      expect(cleared.bio, isNull);

      final seenByBob = await ApiFeedRepository(
        bob.api,
      ).getUserPosts(alice.id, limit: 5);
      final activity = seenByBob.items.singleWhere(
        (p) => p.id == shared.serverId,
      );
      expect(activity.title, plan.name);
      expect(activity.kudosCount, 1);
      expect(activity.commentCount, 1);
      expect(activity.hasKudoed, isTrue);
      expect(activity.isOwn, isFalse);

      final mine = await ApiFeedRepository(alice.api).getUserPosts(alice.id);
      final ownActivity = mine.items.singleWhere(
        (p) => p.id == shared.serverId,
      );
      expect(ownActivity.kudosCount, 1);
      expect(ownActivity.hasKudoed, isFalse);
      expect(ownActivity.isOwn, isTrue);
    });

    test('user search + suggested', () async {
      final found = await ApiProfileRepository(
        bob.api,
      ).searchUsers(alice.firstName);
      final hit = found.singleWhere((u) => u.id == alice.id);
      expect(hit.isFollowing, isTrue);
      expect(hit.handle, isNotEmpty);

      final suggested = await ApiFeedRepository(
        alice.api,
      ).getSuggestedUsers(limit: 5);
      expect(suggested.length, lessThanOrEqualTo(5));
      expect(suggested.map((u) => u.id), isNot(contains(alice.id)));
    });

    test(
      'training history list + detail (/api/v1/training-sessions alias)',
      () async {
        final history = TrainingHistoryRemoteDataSource(alice.api);
        final page = await history.getSessions(
          limit: 10,
          status: TrainingSessionStatus.completed,
        );
        expect(page.isFromCache, isFalse);
        final item = page.items.singleWhere((i) => i.id == shared.serverId);
        expect(item.plan.id, plan.id);
        expect(item.plan.name, plan.name);
        expect(item.status, TrainingSessionStatus.completed);
        expect(item.exercisesCount, 2);
        expect(item.completedSetsCount, 3);
        expect(item.durationSec, 45 * 60);
        expect(item.hasNote, isTrue);
        expect(item.endedAt, isNotNull);

        final filtered = await history.getSessions(query: 'no-such-$e2eRunId');
        expect(filtered.items, isEmpty);

        final detail = await history.getSessionDetail(shared.serverId!);
        expect(detail.id, shared.serverId);
        expect(detail.note, 'Dobra sesja');
        expect(detail.sharedToProfile, isTrue);
        expect(detail.exercises, hasLength(2));
        expect(detail.exercises.first.sets.last.actual?.weightKg, 90);

        // Kształt cache'u = kształt API (round-trip przez cache).
        final roundTrip = history.detailFromCachedJson(
          history.detailToCachedJson(detail),
        );
        expect(roundTrip.exercises.first.sets.last.actual?.weightKg, 90);
        // ETag / 304: klient nie wysyła If-None-Match (cache SWR po stronie
        // aplikacji), więc ścieżka 304 nie jest tu testowana.
      },
    );

    test(
      'sync history: delete → deleted[] with updatedSince, 410 on write',
      () async {
        final remote = TrainingSessionRemoteDataSource(alice.api);

        final full = await remote.history();
        final pulled = full.items.singleWhere(
          (p) => p.session.serverId == shared.serverId,
        );
        expect(pulled.updatedAt, isNotNull);
        expect(pulled.session.id, shared.id);
        expect(pulled.session.sharedToProfile, isTrue);
        expect(full.deleted, isEmpty);

        final since = DateTime.now().toUtc().subtract(
          const Duration(minutes: 1),
        );
        final doomed = await remote.create(
          TrainingSession(
            planName: 'Do usunięcia',
            status: TrainingSessionStatus.completed,
            startedAt: DateTime.now().toUtc().subtract(
              const Duration(hours: 2),
            ),
            finishedAt: DateTime.now().toUtc().subtract(
              const Duration(hours: 1),
            ),
            exercises: [
              TrainingSessionExercise(
                exerciseId: systemExercise.id,
                exerciseName: systemExercise.name,
                exerciseMuscles: const ['chest'],
                exerciseCategory: 'compound',
                sets: [TrainingSessionSet(plannedReps: '5')],
              ),
            ],
          ),
          exerciseServerIdsByLocalId: {systemExercise.id: systemExercise.id},
        );
        await remote.delete(doomed.serverId!);
        await remote.delete(doomed.serverId!); // idempotentne

        final neverSent = const Uuid().v4();
        await remote.deleteByClientId(neverSent);

        final incremental = await remote.history(updatedSince: since);
        expect(
          incremental.items.map((p) => p.session.serverId),
          isNot(contains(doomed.serverId)),
        );
        final tombstone = incremental.deleted.singleWhere(
          (t) => t.id == doomed.serverId,
        );
        expect(tombstone.clientId, doomed.id);
        expect(tombstone.deletedAt, isNotNull);
        expect(incremental.deleted.map((t) => t.clientId), contains(neverSent));

        await expectLater(
          remote.update(
            doomed.serverId!,
            doomed,
            exerciseServerIdsByLocalId: {systemExercise.id: systemExercise.id},
          ),
          throwsA(isApiError('session_deleted', status: 410)),
        );
        await expectLater(
          remote.create(
            doomed,
            exerciseServerIdsByLocalId: {systemExercise.id: systemExercise.id},
          ),
          throwsA(isApiError('session_deleted', status: 410)),
        );

        // Edycja zakończonej sesji (PUT) działa.
        final edited = await remote.update(
          shared.serverId!,
          shared.copyWith(note: 'Po edycji'),
          exerciseServerIdsByLocalId: {
            customExercise.clientId!: customExercise.id,
            systemExercise.id: systemExercise.id,
          },
        );
        expect(edited.note, 'Po edycji');
        expect(edited.serverId, shared.serverId);
      },
    );

    test(
      'uploads resolve against the bare origin; deletes & orphaned refs',
      () async {
        final profiles = ApiProfileRepository(alice.api);
        final withAvatar = await profiles.uploadAvatar(_png1x1, 'blob');
        expect(withAvatar.avatarUrl, startsWith('/uploads/avatars/'));
        final avatarUri = apiAssetUri(withAvatar.avatarUrl, baseUrl: e2eOrigin);
        expect(avatarUri!.path, isNot(contains('/api/v1')));
        final avatarResponse = await http.get(avatarUri);
        expect(avatarResponse.statusCode, 200);
        expect(avatarResponse.bodyBytes, _png1x1);

        final noAvatar = await profiles.removeAvatar();
        expect(noAvatar.avatarUrl, isNull);

        final exercises = ExerciseRemoteDataSource(alice.api);
        final withImage = await exercises.uploadExerciseImage(
          customExercise.id,
          _png1x1,
          'photo.png',
        );
        expect(withImage.imageUrl, startsWith('/uploads/exercise-images/'));
        final imageResponse = await http.get(
          apiAssetUri(withImage.imageUrl, baseUrl: e2eOrigin)!,
        );
        expect(imageResponse.statusCode, 200);

        final renamed = await exercises.update(
          id: customExercise.id,
          name: '${customExercise.name} v2',
          muscles: const [MuscleGroup.chest],
          category: ExerciseCategory.isolation,
          description: '',
        );
        expect(renamed.name, endsWith(' v2'));
        expect(renamed.category, ExerciseCategory.isolation);

        // Ćwiczenie użyte w planie → 409.
        await expectLater(
          exercises.delete(customExercise.id),
          throwsA(isApiError('exercise_in_use', status: 409)),
        );

        final plans = TrainingPlanRemoteDataSource(alice.api);
        final updatedPlan = await plans.update(
          plan.id,
          CustomTrainingPlan(
            id: plan.clientId,
            name: '${plan.name} v2',
            selectedDays: const [2],
            exercises: plan.exercises,
          ),
          exerciseServerIdsByLocalId: {customExercise.id: customExercise.id},
        );
        expect(updatedPlan.name, endsWith(' v2'));
        expect(updatedPlan.selectedDays, [2]);
        await plans.delete(plan.id);
        await exercises.delete(customExercise.id);

        // Sesja wciąż się parsuje, choć ćwiczenie i plan już nie istnieją.
        final pulled = await TrainingSessionRemoteDataSource(
          alice.api,
        ).history();
        final session = pulled.items
            .singleWhere((p) => p.session.serverId == shared.serverId)
            .session;
        expect(session.planName, plan.name);
        expect(session.exercises.first.exerciseName, customExercise.name);
        final detail = await TrainingHistoryRemoteDataSource(
          alice.api,
        ).getSessionDetail(shared.serverId!);
        expect(detail.exercises, hasLength(2));
        final post = await ApiFeedRepository(bob.api).getPost(shared.serverId!);
        expect(post.exercises.first.exerciseName, customExercise.name);
      },
    );

    test(
      'change password → old token revoked, new token works; logout-all',
      () async {
        final oldToken = alice.storage.token!;
        final forcedLogouts = <String>[];
        final session = SessionManager(
          tokenStorage: alice.storage,
          currentUser: ValueNotifier<AuthUser?>(alice.user),
          closeUserScope: () async {},
          wipeUserData: (_) async {},
          onSessionEnded: () => forcedLogouts.add('ended'),
        );
        final api = e2eApiClient(
          alice.storage,
          onUnauthorized: (error, token) =>
              session.handleUnauthorized(error, tokenUsed: token),
        );
        final account = ApiAccountRepository(
          remote: AccountRemoteDataSource(api),
          session: session,
        );

        await expectLater(
          account.changePassword(
            currentPassword: 'Wrong1password',
            newPassword: 'Another1pass',
          ),
          throwsA(isApiError('invalid_credentials')),
        );
        expect(alice.storage.token, oldToken);

        const newPassword = 'Changed1passE2e';
        await account.changePassword(
          currentPassword: e2ePassword,
          newPassword: newPassword,
        );
        final newToken = alice.storage.token!;
        expect(newToken, isNot(oldToken));

        await expectLater(
          ApiProfileRepository(e2eApiClientWithToken(oldToken)).getOwnProfile(),
          throwsA(isApiError('token_revoked', status: 401)),
        );
        final me = await ApiProfileRepository(api).getOwnProfile();
        expect(me.id, alice.id);

        final relogin = await AuthRepository(
          api,
        ).login(email: alice.email, password: newPassword);
        expect(relogin.user.id, alice.id);

        await account.logoutAllDevices();
        final afterLogoutAll = alice.storage.token!;
        expect(afterLogoutAll, isNot(newToken));
        await expectLater(
          ApiProfileRepository(e2eApiClientWithToken(newToken)).getOwnProfile(),
          throwsA(isApiError('token_revoked', status: 401)),
        );
        await expectLater(
          ApiProfileRepository(
            e2eApiClientWithToken(relogin.token),
          ).getOwnProfile(),
          throwsA(isApiError('token_revoked', status: 401)),
        );
        expect((await ApiProfileRepository(api).getOwnProfile()).id, alice.id);
        expect(forcedLogouts, isEmpty);

        // 401 na bieżący token → jedno wymuszone wylogowanie.
        alice.storage.token = newToken;
        await expectLater(
          ApiProfileRepository(api).getOwnProfile(),
          throwsA(isApiError('token_revoked', status: 401)),
        );
        await pumpEventQueue();
        expect(forcedLogouts, ['ended']);
        expect(alice.storage.token, isNull);
        alice.storage.token = afterLogoutAll;
        session.dispose();
      },
    );

    test('delete account via POST /auth/delete-account', () async {
      for (final u in [bob, alice]) {
        final wiped = <String>[];
        final currentUser = ValueNotifier<AuthUser?>(u.user);
        final session = SessionManager(
          tokenStorage: u.storage,
          currentUser: currentUser,
          closeUserScope: () async => currentUser.value = null,
          wipeUserData: (id) async => wiped.add(id),
        );
        final account = ApiAccountRepository(
          remote: AccountRemoteDataSource(u.api),
          session: session,
        );
        final token = u.storage.token!;
        final password = u == alice ? 'Changed1passE2e' : e2ePassword;

        await expectLater(
          account.deleteAccount(password: 'Wrong1password'),
          throwsA(isApiError('invalid_credentials')),
        );
        expect(u.storage.token, token);

        await account.deleteAccount(password: password);
        expect(wiped, [u.id]);
        expect(currentUser.value, isNull);
        expect(u.storage.token, isNull);
        expect(session.loginNotice.value, kAccountDeletedNotice);

        await expectLater(
          ApiProfileRepository(e2eApiClientWithToken(token)).getOwnProfile(),
          throwsA(isApiError('token_revoked', status: 401)),
        );
        session.dispose();
      }
      await expectLater(
        AuthRepository(
          e2eApiClientWithToken(''),
        ).login(email: alice.email, password: 'Changed1passE2e'),
        throwsA(isApiError('invalid_credentials', status: 401)),
      );
    });
  });
}
