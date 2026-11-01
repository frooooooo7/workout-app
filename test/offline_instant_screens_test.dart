import 'dart:async';
import 'dart:convert';
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

UserProfile _profile({
  double? target,
  int? weeklyDays,
  double? weightKg,
  String bio = 'Hej',
}) => UserProfile(
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
    weightKg: weightKg,
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

  final updates = <({ProfileDetails? details, ProfileDetails? baseline})>[];

  /// Waga, którą serwer ma „naprawdę” (np. z pomiaru z innego urządzenia).
  double? serverWeightKg;

  @override
  Future<UserProfile?> cachedOwnProfile() async => cached;

  @override
  Future<UserProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
    String? handle,
    ProfileDetails? details,
    ProfileDetails? detailsBaseline,
  }) async {
    updates.add((details: details, baseline: detailsBaseline));
    final d = details ?? ProfileDetails.empty;
    return _profile().copyWith(
      details: ProfileDetails(
        heightCm: d.heightCm,
        weightKg: serverWeightKg ?? d.weightKg,
        weeklyTrainingDays: d.weeklyTrainingDays,
        targetWeightKg: d.targetWeightKg,
      ),
    );
  }

  @override
  Future<UserProfile> updateTargetWeight(double? kg) async =>
      _profile(target: kg);

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
  Map<String, dynamic>? lastPatch;

  /// Wstrzymuje następny GET (żądanie wiszące na Wi-Fi bez internetu); wynik
  /// to JSON z chwili WYSŁANIA żądania, jak odpowiedź serwera.
  Completer<void>? getGate;

  @override
  Future<dynamic> get(String path, {bool auth = false}) async {
    final snapshot = profileJson;
    final gate = getGate;
    if (gate != null) {
      getGate = null;
      await gate.future;
    }
    return snapshot;
  }

  @override
  Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    lastPatch = body;
    return profileJson = {
      ...profileJson,
      'details': {
        ...(profileJson['details'] as Map<String, dynamic>? ?? const {}),
        if (body.containsKey('targetWeightKg')) ...body,
      },
    };
  }
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
      final cache = DatabaseOwnProfileCache(db, userId: 'me');

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

  group('saving "Dane i cele" from a stale local copy', () {
    test('only the changed fields go to the server', () async {
      final api = _FakeApiClient()..profileJson = _json(target: 75);
      final repo = ApiProfileRepository(api);
      const baseline = ProfileDetails(
        heightCm: 180,
        weightKg: 80,
        weeklyTrainingDays: 3,
        targetWeightKg: 75,
      );

      await repo.updateProfile(
        details: const ProfileDetails(
          heightCm: 182,
          weightKg: 80,
          weeklyTrainingDays: 3,
          targetWeightKg: 75,
        ),
        detailsBaseline: baseline,
      );

      expect(api.lastPatch, {'heightCm': 182});
    });

    test('a cleared field is sent as null, untouched ones are not', () async {
      final api = _FakeApiClient()..profileJson = _json();
      final repo = ApiProfileRepository(api);
      const baseline = ProfileDetails(heightCm: 180, weightKg: 80);

      await repo.updateProfile(
        details: const ProfileDetails(weightKg: 80),
        detailsBaseline: baseline,
      );

      expect(api.lastPatch, {'heightCm': null});
    });

    test('without a baseline every field is still sent', () async {
      final api = _FakeApiClient()..profileJson = _json();
      final repo = ApiProfileRepository(api);

      await repo.updateProfile(details: const ProfileDetails(heightCm: 180));

      expect(api.lastPatch, hasLength(8));
    });

    test('cubit saves against the local copy after a failed refresh without '
        'reverting fields it did not touch', () async {
      final repo = _HangingProfileRepository(cached: _profile(weeklyDays: 3));
      final cubit = ProfileDetailsCubit(repo);

      unawaited(cubit.load());
      repo.fail();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      cubit.updateDraft(cubit.state.draft.copyWith(heightCm: 185));
      await cubit.save();

      final sent = repo.updates.single;
      expect(sent.baseline, _profile(weeklyDays: 3).details);
      expect(sent.details!.changedJson(sent.baseline!), {
        'heightCm': 185,
      }, reason: 'weight, weekly goal and target stay as the server has them');
      await cubit.close();
    });

    test('a newer server weight is not logged as a fake measurement', () async {
      final repo = _HangingProfileRepository(
        cached: _profile(weeklyDays: 3, weightKg: 82),
      )..serverWeightKg = 80;
      final log = FakeBodyWeightRepository();
      final cubit = ProfileDetailsCubit(repo, bodyWeight: log);

      unawaited(cubit.load());
      repo.fail();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      cubit.updateDraft(cubit.state.draft.copyWith(heightCm: 185));
      await cubit.save();

      expect(repo.updates, hasLength(1));
      expect(log.saved, isEmpty);
      await cubit.close();
    });

    test(
      'untouched fields follow the fresh profile, edited ones stay',
      () async {
        final repo = _HangingProfileRepository(cached: _profile(weeklyDays: 3));
        final cubit = ProfileDetailsCubit(repo);

        unawaited(cubit.load());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        cubit.updateDraft(cubit.state.draft.copyWith(heightCm: 185));
        repo.complete(_profile(weeklyDays: 5, target: 70));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await cubit.save();

        final draft = cubit.state.draft;
        expect(draft.heightCm, 185);
        expect(draft.weeklyTrainingDays, 5);
        expect(draft.targetWeightKg, 70);
        final sent = repo.updates.single;
        expect(sent.details!.changedJson(sent.baseline!), {'heightCm': 185});
        await cubit.close();
      },
    );
  });

  group('own profile cache and account switching', () {
    test('a late answer for account A never reaches the cache of B', () async {
      final api = _FakeApiClient()..profileJson = _json(target: 75);
      final cacheA = _MemoryCache();
      final cacheB = _MemoryCache();
      final repo = ApiProfileRepository(api)..attachCache(cacheA);

      final gate = Completer<void>();
      api.getGate = gate;
      final pending = repo.getOwnProfile();
      // Wylogowanie i logowanie na inne konto, zanim odpowiedź dotarła.
      repo.attachCache(null);
      repo.attachCache(cacheB);
      gate.complete();
      await pending;
      await Future<void>.delayed(Duration.zero);

      expect(cacheB.stored, isNull);
      expect(await repo.cachedOwnProfile(), isNull);
    });

    test(
      'database cache of one account never serves or stores another',
      () async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final dir = await Directory.systemTemp.createTemp('gym_profile_owner');
        final db = ExerciseDatabase('o.db', directoryOverride: dir.path);
        addTearDown(() async {
          await db.close();
          await dir.delete(recursive: true);
        });
        await db.writeSyncState(
          DatabaseOwnProfileCache.key,
          jsonEncode(_json(target: 70)),
        );

        final other = DatabaseOwnProfileCache(db, userId: 'someone-else');
        expect(await other.read(), isNull);

        await other.write(_json(target: 99));
        final owner = DatabaseOwnProfileCache(db, userId: 'me');
        expect((await owner.read())?['details']['targetWeightKg'], 70);
      },
    );

    test(
      'an old GET answered after a newer PATCH does not roll the cache back',
      () async {
        final api = _FakeApiClient()..profileJson = _json(target: 75);
        final cache = _MemoryCache();
        final repo = ApiProfileRepository(api)..attachCache(cache);

        api.getGate = Completer<void>();
        final gate = api.getGate!;
        final oldGet = repo.getOwnProfile(); // zobaczy cel 75
        await Future<void>.delayed(Duration.zero);
        await repo.updateTargetWeight(70);
        await Future<void>.delayed(Duration.zero);
        gate.complete();
        await oldGet;
        await Future<void>.delayed(Duration.zero);

        expect((await repo.cachedOwnProfile())?.details?.targetWeightKg, 70);
      },
    );
  });

  test('a stale GET does not revert a weight goal saved meanwhile', () async {
    final repo = _HangingProfileRepository(cached: _profile(target: 75));
    final cubit = BodyWeightCubit(FakeBodyWeightRepository(), profile: repo);

    unawaited(cubit.load());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cubit.state.goalKg, 75);

    await cubit.saveGoal(70);
    repo.complete(_profile(target: 75)); // GET wysłany przed zapisem
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(cubit.state.goalKg, 70);
    await cubit.close();
  });

  test('a stale profile fetch does not revert an edited profile', () async {
    final repo = _HangingProfileRepository(cached: _profile(bio: 'stary'));
    final cubit = ProfileCubit(repo);

    unawaited(cubit.load());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    cubit.applyProfile(_profile(bio: 'nowy'));
    repo.complete(_profile(bio: 'stary'));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(cubit.state.profile?.bio, 'nowy');
    await cubit.close();
  });
}
