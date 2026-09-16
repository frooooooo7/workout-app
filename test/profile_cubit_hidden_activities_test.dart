import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/profile/domain/models/following_user.dart';
import 'package:gym/features/profile/domain/models/profile_activity.dart';
import 'package:gym/features/profile/domain/models/profile_stats.dart';
import 'package:gym/features/profile/domain/models/recent_activity.dart';
import 'package:gym/features/profile/domain/models/user_profile.dart';
import 'package:gym/features/profile/domain/repositories/profile_repository.dart';
import 'package:gym/features/profile/presentation/bloc/profile_cubit.dart';

class _Repo extends Fake implements ProfileRepository {
  bool offline = false;
  List<ProfileActivity> activities = const [];

  @override
  Future<UserProfile> getOwnProfile() async {
    if (offline) throw const ApiException('network_error');
    return const UserProfile(
      id: 'me',
      firstName: 'Jan',
      lastName: 'Kowalski',
      handle: 'jan',
      stats: ProfileStats(
        followingCount: 0,
        followersCount: 0,
        workoutsCount: 2,
      ),
      isOwnProfile: true,
    );
  }

  @override
  Future<List<ProfileActivity>> getRecentActivities({
    int limit = 5,
    String? userId,
  }) async {
    if (offline) throw const ApiException('network_error');
    return activities;
  }

  @override
  Future<List<FollowingUser>> getFollowing({
    int limit = 20,
    int offset = 0,
  }) async {
    if (offline) throw const ApiException('network_error');
    return const [];
  }
}

ProfileActivity _activity(String id) => ProfileActivity(
  id: id,
  kind: RecentActivityKind.strength,
  title: 'Trening $id',
  date: 'dziś',
  duration: '45 min',
);

void main() {
  test('activities of workouts deleted offline are hidden', () async {
    final repo = _Repo()..activities = [_activity('a'), _activity('b')];
    final hidden = <String>{'a'};
    final cubit = ProfileCubit(repo, hiddenActivityIds: () async => hidden);

    await cubit.load();
    expect(cubit.state.highlightActivity?.id, 'b');
    expect(cubit.state.recentActivities, isEmpty);

    // Usunięcie offline: odświeżenie bez sieci i tak chowa aktywność.
    hidden.add('b');
    repo.offline = true;
    await cubit.refresh();

    expect(cubit.state.highlightActivity, isNull);
    expect(cubit.state.recentActivities, isEmpty);
    expect(cubit.state.error, isNotNull);
    await cubit.close();
  });
}
