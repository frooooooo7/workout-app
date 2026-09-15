import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../../../core/network/api_client.dart';
import '../domain/models/follow_result.dart';
import '../domain/models/recent_activity.dart';
import '../domain/models/following_user.dart';
import '../domain/models/profile_activity.dart';
import '../domain/models/profile_activity_stat.dart';
import '../domain/models/profile_stats.dart';
import '../domain/models/user_profile.dart';
import '../domain/repositories/profile_repository.dart';

class ApiProfileRepository implements ProfileRepository {
  const ApiProfileRepository(this._api);

  final ApiClient _api;

  @override
  Future<UserProfile> getOwnProfile() async {
    final data =
        await _api.get('/profile/me', auth: true) as Map<String, dynamic>;
    return userProfileFromJson(data);
  }

  @override
  Future<UserProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
  }) async {
    final body = <String, dynamic>{
      'firstName': ?firstName,
      'lastName': ?lastName,
      'bio': ?bio,
    };
    final data =
        await _api.patch('/profile/me', body, auth: true)
            as Map<String, dynamic>;
    return userProfileFromJson(data);
  }

  @override
  Future<UserProfile> updateBio(String bio) => updateProfile(bio: bio);

  @override
  Future<UserProfile> uploadAvatar(Uint8List bytes, String filename) async {
    final safeName = _normalizeImageFilename(filename);
    final file = http.MultipartFile.fromBytes(
      'avatar',
      bytes,
      filename: safeName,
      contentType: _mediaTypeForImage(safeName),
    );
    final data = await _api.postMultipart(
      '/profile/me/avatar',
      files: [file],
      auth: true,
    );
    return userProfileFromJson(data as Map<String, dynamic>);
  }

  @override
  Future<UserProfile> removeAvatar() async {
    final data = await _api.delete('/profile/me/avatar', auth: true);
    // 204 bez treści — dociągamy aktualny profil.
    if (data is! Map<String, dynamic>) return getOwnProfile();
    return userProfileFromJson(data);
  }

  @override
  Future<UserProfile> getUserProfile(String userId) async {
    final data = await _api.get('/users/$userId/profile', auth: true)
        as Map<String, dynamic>;
    return userProfileFromJson(data);
  }

  @override
  Future<FollowResult> follow(String userId) async {
    final data = await _api.post(
      '/users/$userId/follow',
      const <String, dynamic>{},
      auth: true,
    );
    return _followResultFromJson(data);
  }

  @override
  Future<FollowResult> unfollow(String userId) async {
    final data = await _api.delete('/users/$userId/follow', auth: true);
    return _followResultFromJson(data);
  }

  @override
  Future<List<FollowingUser>> getFollowing({
    int limit = 20,
    int offset = 0,
  }) {
    return _getUserList('/profile/following', limit: limit, offset: offset);
  }

  @override
  Future<List<FollowingUser>> getFollowers({
    int limit = 20,
    int offset = 0,
  }) {
    return _getUserList('/profile/followers', limit: limit, offset: offset);
  }

  @override
  Future<List<FollowingUser>> getUserFollowing(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) {
    return _getUserList(
      '/users/$userId/following',
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<FollowingUser>> getUserFollowers(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) {
    return _getUserList(
      '/users/$userId/followers',
      limit: limit,
      offset: offset,
    );
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
    return followingUsersFromJson(await _api.get(path, auth: true));
  }

  Future<List<FollowingUser>> _getUserList(
    String basePath, {
    required int limit,
    required int offset,
  }) async {
    final path = Uri(
      path: basePath,
      queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
      },
    ).toString();
    return followingUsersFromJson(await _api.get(path, auth: true));
  }

  static UserProfile userProfileFromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? const {};
    return UserProfile(
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      handle: json['handle'] as String,
      bio: json['bio'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      stats: ProfileStats(
        followingCount: (stats['followingCount'] as num?)?.toInt() ?? 0,
        followersCount: (stats['followersCount'] as num?)?.toInt() ?? 0,
        workoutsCount: (stats['workoutsCount'] as num?)?.toInt() ?? 0,
      ),
      isOwnProfile: json['isOwnProfile'] as bool? ?? false,
      isFollowing: json['isFollowing'] as bool? ?? false,
      isFollowedBy: json['isFollowedBy'] as bool? ?? false,
    );
  }

  static List<FollowingUser> followingUsersFromJson(dynamic data) {
    if (data is! List) return const [];
    return data
        .cast<Map<String, dynamic>>()
        .map(
          (json) => FollowingUser(
            id: json['id'] as String,
            firstName: json['firstName'] as String,
            lastName: json['lastName'] as String,
            handle: json['handle'] as String,
            avatarUrl: json['avatarUrl'] as String?,
            isFollowing: json['isFollowing'] as bool? ?? false,
          ),
        )
        .toList(growable: false);
  }

  static FollowResult _followResultFromJson(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw const ApiException('invalid_response', statusCode: 200);
    }
    final isFollowing = data['isFollowing'];
    final followersCount = data['followersCount'];
    if (isFollowing is! bool || followersCount is! num) {
      throw const ApiException('invalid_response', statusCode: 200);
    }
    return FollowResult(
      isFollowing: isFollowing,
      followersCount: followersCount.toInt(),
    );
  }

  /// Web często podaje nazwę `blob` bez rozszerzenia — backend i wykrywanie
  /// MIME potrzebują prawdziwego rozszerzenia.
  static String _normalizeImageFilename(String filename) {
    var name = filename.trim();
    if (name.isEmpty || name.toLowerCase() == 'blob') {
      name = 'avatar.jpg';
    }
    final lower = name.toLowerCase();
    final hasExt =
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
    if (!hasExt) {
      name = '$name.jpg';
    }
    return name;
  }

  static MediaType _mediaTypeForImage(String filename) {
    final typed = lookupMimeType(filename);
    if (typed != null) return MediaType.parse(typed);
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }

  List<ProfileActivity> _activitiesFromJson(dynamic data) {
    if (data is! List) return const [];
    return data
        .cast<Map<String, dynamic>>()
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
        .cast<Map<String, dynamic>>()
        .map(
          (json) => ProfileActivityStat(
            label: json['label'] as String? ?? '',
            value: json['value'] as String? ?? '',
          ),
        )
        .toList(growable: false);
  }

  RecentActivityKind _kindFromApi(String? _) => RecentActivityKind.strength;
}
