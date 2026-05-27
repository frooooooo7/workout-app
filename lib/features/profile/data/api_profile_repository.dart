import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../../../core/network/api_asset_uri.dart';
import '../../../core/network/api_client.dart';
import '../../home/domain/models/recent_activity.dart';
import '../domain/models/following_user.dart';
import '../domain/models/profile_activity.dart';
import '../domain/models/profile_activity_stat.dart';
import '../domain/models/profile_stats.dart';
import '../domain/models/profile_update_input.dart';
import '../domain/models/user_profile.dart';
import '../domain/repositories/profile_repository.dart';

class ApiProfileRepository implements ProfileRepository {
  const ApiProfileRepository(this._api);

  final ApiClient _api;

  @override
  Future<UserProfile> getOwnProfile() async {
    final data =
        await _api.get('/profile/me', auth: true) as Map<String, dynamic>;
    return _userProfileFromJson(data);
  }

  @override
  Future<UserProfile> updateBio(String bio) =>
      updateProfile(ProfileUpdateInput(bio: bio));

  @override
  Future<UserProfile> updateProfile(ProfileUpdateInput input) async {
    final data = await _api.patch('/profile/me', input.toJson(), auth: true)
        as Map<String, dynamic>;
    return _userProfileFromJson(data);
  }

  @override
  Future<UserProfile> uploadAvatar(Uint8List bytes, String filename) async {
    final safeName = _normalizeAvatarFilename(filename);
    final file = http.MultipartFile.fromBytes(
      'avatar',
      bytes,
      filename: safeName,
      contentType: _mediaTypeForAvatar(safeName),
    );
    final data = await _api.postMultipart(
      '/profile/me/avatar',
      files: [file],
      auth: true,
    );
    return _userProfileFromJson(data as Map<String, dynamic>);
  }

  @override
  Future<UserProfile> getUserProfile(String userId) async {
    final data = await _api.get('/users/$userId/profile', auth: true)
        as Map<String, dynamic>;
    return _userProfileFromJson(data);
  }

  @override
  Future<List<FollowingUser>> getFollowing({
    int limit = 20,
    int offset = 0,
  }) async {
    final path = Uri(
      path: '/profile/following',
      queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
      },
    ).toString();
    return _followingUsersFromJson(await _api.get(path, auth: true));
  }

  @override
  Future<List<FollowingUser>> getFollowers({
    int limit = 20,
    int offset = 0,
  }) async {
    final path = Uri(
      path: '/profile/followers',
      queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
      },
    ).toString();
    return _followingUsersFromJson(await _api.get(path, auth: true));
  }

  @override
  Future<List<ProfileActivity>> getRecentActivities({
    int limit = 5,
    String? userId,
  }) async {
    final path = userId == null
        ? Uri(
            path: '/profile/activities',
            queryParameters: {'limit': '$limit'},
          ).toString()
        : Uri(
            path: '/users/$userId/activities',
            queryParameters: {'limit': '$limit'},
          ).toString();
    return _activitiesFromJson(await _api.get(path, auth: true));
  }

  @override
  Future<List<FollowingUser>> searchUsers(String query) async {
    final path = Uri(
      path: '/users/search',
      queryParameters: {
        'q': query.trim(),
        'limit': '20',
      },
    ).toString();
    return _followingUsersFromJson(await _api.get(path, auth: true));
  }

  UserProfile _userProfileFromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? const {};
    return UserProfile(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      handle: json['handle'] as String,
      bio: json['bio'] as String?,
      avatarUrl: resolveApiAssetUrl(json['avatarUrl'] as String?),
      stats: ProfileStats(
        followingCount: (stats['followingCount'] as num?)?.toInt() ?? 0,
        followersCount: (stats['followersCount'] as num?)?.toInt() ?? 0,
        workoutsCount: (stats['workoutsCount'] as num?)?.toInt() ?? 0,
      ),
      isOwnProfile: json['isOwnProfile'] as bool? ?? false,
    );
  }

  List<FollowingUser> _followingUsersFromJson(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => FollowingUser(
            id: json['id'] as String,
            firstName: json['firstName'] as String,
            lastName: json['lastName'] as String,
            handle: json['handle'] as String,
            avatarUrl: resolveApiAssetUrl(json['avatarUrl'] as String?),
          ),
        )
        .toList(growable: false);
  }

  List<ProfileActivity> _activitiesFromJson(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => ProfileActivity(
            id: json['id'] as String?,
            kind: _kindFromApi(json['kind'] as String?),
            title: json['title'] as String? ?? '',
            date: json['date'] as String? ?? '',
            duration: json['duration'] as String? ?? '',
            detail: json['detail'] as String?,
            timeLabel: json['timeLabel'] as String?,
            stats: _statsFromJson(json['stats']),
            kudosCount: (json['kudosCount'] as num?)?.toInt() ?? 0,
            commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false);
  }

  List<ProfileActivityStat> _statsFromJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => ProfileActivityStat(
            label: json['label'] as String? ?? '',
            value: json['value'] as String? ?? '',
          ),
        )
        .toList(growable: false);
  }

  RecentActivityKind _kindFromApi(String? raw) {
    return switch (raw) {
      'run' => RecentActivityKind.run,
      'cycling' => RecentActivityKind.cycling,
      'yoga' => RecentActivityKind.yoga,
      _ => RecentActivityKind.strength,
    };
  }

  String _normalizeAvatarFilename(String filename) {
    final base = filename.split('/').last.split('\\').last;
    final dotIndex = base.lastIndexOf('.');
    final ext = dotIndex >= 0 ? base.substring(dotIndex).toLowerCase() : '.jpg';
    const allowed = {'.jpg', '.jpeg', '.png', '.webp'};
    final safeExt = allowed.contains(ext) ? ext : '.jpg';
    return 'avatar$safeExt';
  }

  MediaType _mediaTypeForAvatar(String filename) {
    final mime = lookupMimeType(filename);
    if (mime != null) return MediaType.parse(mime);
    return MediaType('image', 'jpeg');
  }
}
