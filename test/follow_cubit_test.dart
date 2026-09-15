import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/profile/domain/models/follow_result.dart';
import 'package:gym/features/profile/domain/models/following_user.dart';
import 'package:gym/features/profile/domain/models/profile_stats.dart';
import 'package:gym/features/profile/domain/models/user_profile.dart';
import 'package:gym/features/profile/domain/repositories/profile_repository.dart';
import 'package:gym/features/profile/presentation/bloc/follow_cubit.dart';

class _FakeFollowRepository extends Fake implements ProfileRepository {
  final followCalls = <String>[];
  final unfollowCalls = <String>[];
  Completer<FollowResult>? pending;

  @override
  Future<FollowResult> follow(String userId) {
    followCalls.add(userId);
    return (pending = Completer<FollowResult>()).future;
  }

  @override
  Future<FollowResult> unfollow(String userId) {
    unfollowCalls.add(userId);
    return (pending = Completer<FollowResult>()).future;
  }
}

UserProfile _profile({required bool isFollowing, int followersCount = 5}) {
  return UserProfile(
    id: 'u1',
    firstName: 'Anna',
    lastName: 'Nowak',
    handle: 'anna',
    stats: ProfileStats(
      followingCount: 1,
      followersCount: followersCount,
      workoutsCount: 3,
    ),
    isOwnProfile: false,
    isFollowing: isFollowing,
  );
}

void main() {
  test('toggle follows optimistically and applies server response', () async {
    final repo = _FakeFollowRepository();
    var changes = 0;
    final cubit = FollowCubit(repo, onFollowChanged: () => changes++);
    cubit.seedProfile(_profile(isFollowing: false, followersCount: 5));

    final future = cubit.toggle('u1');

    expect(cubit.state.isFollowing('u1'), isTrue);
    expect(cubit.state.isPending('u1'), isTrue);
    expect(cubit.state.followersCountOf('u1'), 6);
    expect(repo.followCalls, ['u1']);

    repo.pending!.complete(
      const FollowResult(isFollowing: true, followersCount: 9),
    );
    await future;

    expect(cubit.state.isFollowing('u1'), isTrue);
    expect(cubit.state.isPending('u1'), isFalse);
    expect(cubit.state.followersCountOf('u1'), 9);
    expect(cubit.state.failure, isNull);
    expect(changes, 1);
    await cubit.close();
  });

  test('toggle reverts and reports a Polish error when unfollow fails',
      () async {
    final repo = _FakeFollowRepository();
    var changes = 0;
    final cubit = FollowCubit(repo, onFollowChanged: () => changes++);
    cubit.seedProfile(_profile(isFollowing: true, followersCount: 5));

    final future = cubit.toggle('u1');
    expect(cubit.state.isFollowing('u1'), isFalse);
    expect(cubit.state.followersCountOf('u1'), 4);
    expect(repo.unfollowCalls, ['u1']);

    repo.pending!.completeError(const ApiException('network_error'));
    await future;

    expect(cubit.state.isFollowing('u1'), isTrue);
    expect(cubit.state.isPending('u1'), isFalse);
    expect(cubit.state.followersCountOf('u1'), 5);
    expect(cubit.state.failure, isNotNull);
    expect(cubit.state.failure!.userId, 'u1');
    expect(cubit.state.failure!.message, startsWith('Nie udało się'));
    expect(cubit.state.failure!.message, contains('brak połączenia'));
    expect(changes, 0);
    await cubit.close();
  });

  test('toggle is ignored while a request for the user is in flight', () async {
    final repo = _FakeFollowRepository();
    final cubit = FollowCubit(repo);
    cubit.seedUsers(const [
      FollowingUser(id: 'u1', firstName: 'A', lastName: 'B', handle: 'ab'),
    ]);

    final first = cubit.toggle('u1');
    await cubit.toggle('u1');

    expect(repo.followCalls, ['u1']);
    expect(repo.unfollowCalls, isEmpty);

    repo.pending!.completeError(
      const ApiException('user_not_found', statusCode: 404),
    );
    await first;
    expect(cubit.state.isFollowing('u1'), isFalse);
    expect(cubit.state.failure!.id, 1);
    await cubit.close();
  });

  test('seedUsers does not override users with a pending request', () async {
    final repo = _FakeFollowRepository();
    final cubit = FollowCubit(repo);
    cubit.seedUsers(const [
      FollowingUser(id: 'u1', firstName: 'A', lastName: 'B', handle: 'ab'),
      FollowingUser(
        id: 'u2',
        firstName: 'C',
        lastName: 'D',
        handle: 'cd',
        isFollowing: true,
      ),
    ]);
    expect(cubit.state.isFollowing('u2'), isTrue);

    final future = cubit.toggle('u1');
    cubit.seedUsers(const [
      FollowingUser(id: 'u1', firstName: 'A', lastName: 'B', handle: 'ab'),
    ]);
    expect(cubit.state.isFollowing('u1'), isTrue);

    repo.pending!.complete(
      const FollowResult(isFollowing: true, followersCount: 1),
    );
    await future;
    expect(cubit.state.isFollowing('u1'), isTrue);
    await cubit.close();
  });
}
