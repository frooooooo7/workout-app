import '../../auth/domain/models/auth_models.dart';
import '../../home/domain/models/recent_activity.dart';
import '../../home/presentation/widgets/recent_activities_card.dart';
import '../domain/models/following_user.dart';
import '../domain/models/profile_activity.dart';
import '../domain/models/profile_activity_stat.dart';
import '../domain/models/profile_stats.dart';
import '../domain/models/user_profile.dart';
import '../domain/repositories/profile_repository.dart';
import 'profile_bio_storage.dart';

class MockProfileRepository implements ProfileRepository {
  MockProfileRepository({
    required AuthUser user,
    ProfileBioStorage bioStorage = const ProfileBioStorage(),
  })  : _user = user,
        _bioStorage = bioStorage;

  final AuthUser _user;
  final ProfileBioStorage _bioStorage;

  static const _mockFollowing = [
    FollowingUser(
      id: 'u1',
      firstName: 'Anna',
      lastName: 'Nowak',
      handle: 'annanowak',
    ),
    FollowingUser(
      id: 'u2',
      firstName: 'Piotr',
      lastName: 'Wiśniewski',
      handle: 'piotr_w',
    ),
    FollowingUser(
      id: 'u3',
      firstName: 'Kasia',
      lastName: 'Kowalska',
      handle: 'kasiak',
    ),
    FollowingUser(
      id: 'u4',
      firstName: 'Michał',
      lastName: 'Lewandowski',
      handle: 'm_lewandowski',
    ),
    FollowingUser(
      id: 'u5',
      firstName: 'Ola',
      lastName: 'Zielińska',
      handle: 'olaz',
    ),
    FollowingUser(
      id: 'u6',
      firstName: 'Tomek',
      lastName: 'Wójcik',
      handle: 'tomekw',
    ),
    FollowingUser(
      id: 'u7',
      firstName: 'Magda',
      lastName: 'Kamińska',
      handle: 'magdak',
    ),
    FollowingUser(
      id: 'u8',
      firstName: 'Kuba',
      lastName: 'Szymański',
      handle: 'kubasz',
    ),
  ];

  static const _mockFollowers = [
    FollowingUser(
      id: 'f1',
      firstName: 'Ewa',
      lastName: 'Dąbrowska',
      handle: 'ewad',
    ),
    FollowingUser(
      id: 'f2',
      firstName: 'Marcin',
      lastName: 'Kozłowski',
      handle: 'marcink',
    ),
    FollowingUser(
      id: 'f3',
      firstName: 'Julia',
      lastName: 'Mazur',
      handle: 'juliam',
    ),
    FollowingUser(
      id: 'f4',
      firstName: 'Bartek',
      lastName: 'Jankowski',
      handle: 'bartekj',
    ),
    FollowingUser(
      id: 'f5',
      firstName: 'Natalia',
      lastName: 'Wojcik',
      handle: 'nataliaw',
    ),
  ];

  static const _searchableUsers = [
    ..._mockFollowing,
    ..._mockFollowers,
    FollowingUser(
      id: 's1',
      firstName: 'Adam',
      lastName: 'Malinowski',
      handle: 'adamm',
    ),
    FollowingUser(
      id: 's2',
      firstName: 'Zosia',
      lastName: 'Piotrowska',
      handle: 'zosiap',
    ),
    FollowingUser(
      id: 's3',
      firstName: 'Damian',
      lastName: 'Grabowski',
      handle: 'damiang',
    ),
  ];

  static String handleFromUser(AuthUser user) {
    final raw = '${user.firstName}.${user.lastName}'.toLowerCase();
    return raw
        .replaceAll('ą', 'a')
        .replaceAll('ć', 'c')
        .replaceAll('ę', 'e')
        .replaceAll('ł', 'l')
        .replaceAll('ń', 'n')
        .replaceAll('ó', 'o')
        .replaceAll('ś', 's')
        .replaceAll('ź', 'z')
        .replaceAll('ż', 'z')
        .replaceAll(RegExp(r'[^a-z0-9._]'), '');
  }

  @override
  Future<UserProfile> getOwnProfile() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final bio = await _bioStorage.read(_user.id);
    return UserProfile(
      id: _user.id,
      firstName: _user.firstName,
      lastName: _user.lastName,
      handle: handleFromUser(_user),
      bio: bio,
      stats: const ProfileStats(
        followingCount: 24,
        followersCount: 18,
        workoutsCount: 142,
      ),
      isOwnProfile: true,
    );
  }

  @override
  Future<UserProfile> updateBio(String bio) async {
    await _bioStorage.write(_user.id, bio);
    return getOwnProfile();
  }

  @override
  Future<UserProfile> getUserProfile(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final match = _searchableUsers.where((u) => u.id == userId).firstOrNull;
    if (match == null) {
      throw Exception('User not found');
    }
    return UserProfile(
      id: match.id,
      firstName: match.firstName,
      lastName: match.lastName,
      handle: match.handle,
      bio: 'Aktywny/a w aplikacji Gym',
      stats: ProfileStats(
        followingCount: 12 + match.id.hashCode % 20,
        followersCount: 8 + match.id.hashCode % 15,
        workoutsCount: 30 + match.id.hashCode % 100,
      ),
      isOwnProfile: false,
    );
  }

  @override
  Future<List<FollowingUser>> getFollowing({
    int limit = 20,
    int offset = 0,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return _slice(_mockFollowing, limit, offset);
  }

  @override
  Future<List<FollowingUser>> getFollowers({
    int limit = 20,
    int offset = 0,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return _slice(_mockFollowers, limit, offset);
  }

  @override
  Future<List<ProfileActivity>> getRecentActivities({int limit = 5}) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return RecentActivitiesCard.mockActivities
        .asMap()
        .entries
        .map((e) => _mapActivity(e.value, index: e.key))
        .take(limit)
        .toList();
  }

  @override
  Future<List<FollowingUser>> searchUsers(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _searchableUsers;
    return _searchableUsers
        .where(
          (u) =>
              u.fullName.toLowerCase().contains(q) ||
              u.handle.toLowerCase().contains(q),
        )
        .toList();
  }

  List<T> _slice<T>(List<T> list, int limit, int offset) {
    if (offset >= list.length) return [];
    final end = (offset + limit).clamp(0, list.length);
    return list.sublist(offset, end);
  }

  ProfileActivity _mapActivity(RecentActivity activity, {int index = 0}) {
    final stats = _statsFor(activity);
    return ProfileActivity(
      kind: activity.kind,
      title: activity.title,
      date: activity.date,
      duration: activity.duration,
      detail: activity.detail,
      timeLabel: _timeLabels[index % _timeLabels.length],
      stats: stats,
      kudosCount: 3 + index * 4,
      commentCount: index,
    );
  }

  static const _timeLabels = ['18:32', '07:15', '19:48', '12:05', '16:20'];

  List<ProfileActivityStat> _statsFor(RecentActivity activity) {
    return switch (activity.kind) {
      RecentActivityKind.strength => [
          ProfileActivityStat(label: 'Czas', value: activity.duration),
          ProfileActivityStat(label: 'Ćwiczenia', value: activity.detail ?? '—'),
          const ProfileActivityStat(label: 'Objętość', value: '6 450 kg'),
        ],
      RecentActivityKind.run => [
          ProfileActivityStat(label: 'Czas', value: activity.duration),
          ProfileActivityStat(label: 'Dystans', value: activity.detail ?? '—'),
          const ProfileActivityStat(label: 'Tempo', value: '6:32 /km'),
        ],
      RecentActivityKind.cycling => [
          ProfileActivityStat(label: 'Czas', value: activity.duration),
          ProfileActivityStat(label: 'Dystans', value: activity.detail ?? '—'),
          const ProfileActivityStat(label: 'Prędkość', value: '23,6 km/h'),
        ],
      RecentActivityKind.yoga => [
          ProfileActivityStat(label: 'Czas', value: activity.duration),
          const ProfileActivityStat(label: 'Kalorie', value: '186 kcal'),
          const ProfileActivityStat(label: 'Strefa', value: 'Spokojna'),
        ],
    };
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
