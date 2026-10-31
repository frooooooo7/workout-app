import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/library/data/exercise_database.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/library/presentation/widgets/exercise_details/exercise_details_hero.dart';
import 'package:gym/features/profile/data/api_profile_repository.dart';
import 'package:gym/features/profile/data/own_profile_cache.dart';
import 'package:gym/features/profile/domain/models/following_user.dart';
import 'package:gym/features/profile/domain/models/profile_details.dart';
import 'package:gym/features/profile/domain/models/profile_stats.dart';
import 'package:gym/features/profile/domain/models/user_profile.dart';
import 'package:gym/features/profile/domain/repositories/profile_repository.dart';
import 'package:gym/features/profile/presentation/bloc/body_weight_cubit.dart';
import 'package:gym/features/profile/presentation/bloc/profile_cubit.dart';
import 'package:gym/features/profile/presentation/bloc/profile_details_cubit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'body_weight_test.dart' show FakeBodyWeightRepository;

UserProfile _profile({double? target, int? weeklyDays, String bio = 'Hej'}) =>
    UserProfile(
      id: 'me',
      firstName: 'Jan',
      lastName: 'Kowalski',
      handle: 'jan',
      bio: bio,
      stats: const ProfileStats(
        followingCount: 1,
        followersCount: 2,
        workoutsCount: 3,
      ),
      isOwnProfile: true,
      details: ProfileDetails(
        heightCm: 180,
        targetWeightKg: target,
        weeklyTrainingDays: weeklyDays,
      ),
    );

/// Profil z lokalną kopią; `GET /profile/me` wisi do [complete]/[fail], jak
/// zapytanie na Wi-Fi bez internetu.
class _HangingProfileRepository extends Fake implements ProfileRepository {
  _HangingProfileRepository({this.cached});

  UserProfile? cached;
  final _server = Completer<UserProfile>();
  var serverCalls = 0;

  void complete(UserProfile profile) => _server.complete(profile);

  void fail() => _server.completeError(const ApiException('network_error'));

  @override
  Future<UserProfile?> cachedOwnProfile() async => cached;

  @override
  Future<UserProfile> getOwnProfile() {
    serverCalls++;
    return _server.future;
  }

  @override
  Future<List<FollowingUser>> getFollowing({int limit = 20, int offset = 0}) =>
      _server.future.then((_) => const <FollowingUser>[]);
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://test.local');

  Map<String, dynamic> profileJson = {};

  @override
  Future<dynamic> get(String path, {bool auth = false}) async => profileJson;

  @override
  Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async => profileJson = {
    ...profileJson,
    'details': {
      ...(profileJson['details'] as Map<String, dynamic>? ?? const {}),
      if (body.containsKey('targetWeightKg'))
        'targetWeightKg': body['targetWeightKg'],
    },
  };
}

class _MemoryCache implements OwnProfileCache {
  Map<String, dynamic>? stored;
  Object? writeError;

  @override
  Future<Map<String, dynamic>?> read() async => stored;

  @override
  Future<void> write(Map<String, dynamic> json) async {
    if (writeError != null) throw writeError!;
    stored = json;
  }
}

Map<String, dynamic> _json({double? target}) => {
  'id': 'me',
  'firstName': 'Jan',
  'lastName': 'Kowalski',
  'handle': 'jan',
  'isOwnProfile': true,
  'stats': {'followingCount': 0, 'followersCount': 0, 'workoutsCount': 4},
  'details': {'heightCm': 180, 'targetWeightKg': ?target},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('own profile cache', () {
    test(
      'profile reads fill the cache and cachedOwnProfile returns it',
      () async {
        final api = _FakeApiClient()..profileJson = _json(target: 75);
        final cache = _MemoryCache();
        final repo = ApiProfileRepository(api)..attachCache(cache);

        expect(await repo.cachedOwnProfile(), isNull);
        await repo.getOwnProfile();
        await Future<void>.delayed(Duration.zero);

        final cached = await repo.cachedOwnProfile();
        expect(cached?.details?.targetWeightKg, 75);
        expect(cached?.stats.workoutsCount, 4);

        await repo.updateTargetWeight(70);
        await Future<void>.delayed(Duration.zero);
        expect((await repo.cachedOwnProfile())?.details?.targetWeightKg, 70);
      },
    );

    test('a broken cache never breaks the profile', () async {
      final api = _FakeApiClient()..profileJson = _json();
      final cache = _MemoryCache()..writeError = StateError('db closing');
      final repo = ApiProfileRepository(api)..attachCache(cache);
      expect((await repo.getOwnProfile()).handle, 'jan');

      cache.stored = {'garbage': true};
      expect(await repo.cachedOwnProfile(), isNull);

      repo.attachCache(null);
      expect(await repo.cachedOwnProfile(), isNull);
    });

    test('database cache keeps the last profile on disk', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await Directory.systemTemp.createTemp('gym_profile_cache');
      final db = ExerciseDatabase('p.db', directoryOverride: dir.path);
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      final cache = DatabaseOwnProfileCache(db);

      expect(await cache.read(), isNull);
      await cache.write(_json(target: 72.5));

      expect(await cache.read(), _json(target: 72.5));
    });
  });

  group('ProfileDetailsCubit with a hanging server', () {
    test('opens from the local copy and refreshes in the background', () async {
      final repo = _HangingProfileRepository(cached: _profile(weeklyDays: 3));
      final cubit = ProfileDetailsCubit(repo);

      unawaited(cubit.load());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.loading, isFalse);
      expect(cubit.state.initial?.details?.weeklyTrainingDays, 3);
      expect(cubit.state.draft.weeklyTrainingDays, 3);
      expect(cubit.state.refreshing, isTrue);
      expect(cubit.state.canSave, isFalse);

      repo.complete(_profile(weeklyDays: 5));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.refreshing, isFalse);
      expect(cubit.state.draft.weeklyTrainingDays, 5);
      await cubit.close();
    });

    test('offline refresh keeps the local copy without an error', () async {
      final repo = _HangingProfileRepository(cached: _profile(weeklyDays: 3));
      final cubit = ProfileDetailsCubit(repo);

      unawaited(cubit.load());
      repo.fail();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.loadError, isNull);
      expect(cubit.state.refreshing, isFalse);
      expect(cubit.state.initial?.details?.weeklyTrainingDays, 3);
      await cubit.close();
    });

    test('a draft edited before the refresh arrives is kept', () async {
      final repo = _HangingProfileRepository(cached: _profile(weeklyDays: 3));
      final cubit = ProfileDetailsCubit(repo);

      unawaited(cubit.load());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      cubit.updateDraft(cubit.state.draft.copyWith(weeklyTrainingDays: 4));
      repo.complete(_profile(weeklyDays: 5));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cubit.state.draft.weeklyTrainingDays, 4);
      expect(cubit.state.initial?.details?.weeklyTrainingDays, 5);
      expect(cubit.state.canSave, isTrue);
      await cubit.close();
    });

    test('without a local copy it still waits for the server', () async {
      final repo = _HangingProfileRepository();
      final cubit = ProfileDetailsCubit(repo);

      unawaited(cubit.load());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(cubit.state.loading, isTrue);

      repo.fail();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(cubit.state.loading, isFalse);
      expect(cubit.state.loadError, contains('Brak połączenia'));
      await cubit.close();
    });
  });

  test('body weight goal shows from the local copy at once', () async {
    final repo = _HangingProfileRepository(cached: _profile(target: 75));
    final cubit = BodyWeightCubit(FakeBodyWeightRepository(), profile: repo);

    unawaited(cubit.load());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(cubit.state.goalLoaded, isTrue);
    expect(cubit.state.goalKg, 75);

    repo.complete(_profile(target: 72));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state.goalKg, 72);
    await cubit.close();
  });

  test('profile screen data shows from the local copy at once', () async {
    final repo = _HangingProfileRepository(cached: _profile());
    final cubit = ProfileCubit(repo);

    unawaited(cubit.load());
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(cubit.state.profile?.handle, 'jan');
    expect(cubit.state.loading, isFalse);
    expect(repo.serverCalls, 1);

    repo.fail();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state.profile?.handle, 'jan');
    expect(cubit.state.offline, isTrue);
    await cubit.close();
  });

  testWidgets('exercise hero shows its backdrop while the image loads', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          height: 300,
          child: ExerciseDetailsHero(
            exercise: Exercise(
              id: 'e1',
              name: 'Wyciskanie',
              muscles: [MuscleGroup.chest],
              category: ExerciseCategory.compound,
              imageUrl: 'http://localhost:1/image.png',
            ),
          ),
        ),
      ),
    );

    // Obrazek jeszcze się wczytuje (offline do 20 s) — tło z ikoną już jest.
    expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });
}
