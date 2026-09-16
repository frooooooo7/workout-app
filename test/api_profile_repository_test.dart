import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/profile/data/api_profile_repository.dart';
import 'package:http/http.dart' as http;

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://test.local');

  final calls = <String>[];
  final responses = <String, dynamic>{};
  Map<String, dynamic>? lastBody;
  List<http.MultipartFile>? lastFiles;

  dynamic _respond(String method, String path) {
    final key = '$method $path';
    calls.add(key);
    return responses[key];
  }

  @override
  Future<dynamic> get(String path, {bool auth = false}) async =>
      _respond('GET', path);

  @override
  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    lastBody = body;
    return _respond('POST', path);
  }

  @override
  Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    lastBody = body;
    return _respond('PATCH', path);
  }

  @override
  Future<dynamic> delete(String path, {bool auth = false}) async =>
      _respond('DELETE', path);

  @override
  Future<dynamic> postMultipart(
    String path, {
    required List<http.MultipartFile> files,
    Map<String, String> fields = const {},
    bool auth = false,
  }) async {
    lastFiles = files;
    return _respond('MULTIPART', path);
  }
}

Map<String, dynamic> _profileJson({
  String? avatarUrl,
  bool? isFollowing,
  bool? isFollowedBy,
}) {
  return {
    'id': 'u1',
    'firstName': 'Jan',
    'lastName': 'Kowalski',
    'handle': 'jan.kowalski_ab12cd',
    'bio': null,
    'avatarUrl': avatarUrl,
    'stats': {'followingCount': 3, 'followersCount': 5, 'workoutsCount': 12},
    'isOwnProfile': false,
    'isFollowing': ?isFollowing,
    'isFollowedBy': ?isFollowedBy,
  };
}

void main() {
  late _FakeApiClient api;
  late ApiProfileRepository repository;

  setUp(() {
    api = _FakeApiClient();
    repository = ApiProfileRepository(api);
  });

  test('getUserProfile parses follow flags, avatar and stats', () async {
    api.responses['GET /users/u1/profile'] = _profileJson(
      avatarUrl: '/uploads/avatars/a.jpg',
      isFollowing: true,
      isFollowedBy: true,
    );

    final profile = await repository.getUserProfile('u1');

    expect(profile.isFollowing, isTrue);
    expect(profile.isFollowedBy, isTrue);
    expect(profile.avatarUrl, '/uploads/avatars/a.jpg');
    expect(profile.stats.followersCount, 5);
    expect(profile.stats.workoutsCount, 12);
  });

  test('missing follow flags default to false', () async {
    api.responses['GET /profile/me'] = _profileJson();

    final profile = await repository.getOwnProfile();

    expect(profile.isFollowing, isFalse);
    expect(profile.isFollowedBy, isFalse);
    expect(profile.avatarUrl, isNull);
  });

  test('getUserFollowers calls the user endpoint and parses isFollowing',
      () async {
    api.responses['GET /users/u1/followers?limit=20&offset=40'] = [
      {
        'id': 'u2',
        'firstName': 'Anna',
        'lastName': 'Nowak',
        'handle': 'anna',
        'avatarUrl': null,
        'isFollowing': true,
      },
      {
        'id': 'u3',
        'firstName': 'Piotr',
        'lastName': 'Wiśniewski',
        'handle': 'piotr',
        'avatarUrl': '/uploads/avatars/p.png',
      },
    ];

    final users = await repository.getUserFollowers('u1', offset: 40);

    expect(users.map((u) => u.id), ['u2', 'u3']);
    expect(users[0].isFollowing, isTrue);
    expect(users[1].isFollowing, isFalse);
    expect(users[1].avatarUrl, '/uploads/avatars/p.png');
  });

  test('follow and unfollow parse FollowResult', () async {
    api.responses['POST /users/u1/follow'] = {
      'isFollowing': true,
      'followersCount': 6,
    };
    api.responses['DELETE /users/u1/follow'] = {
      'isFollowing': false,
      'followersCount': 5,
    };

    final followed = await repository.follow('u1');
    final unfollowed = await repository.unfollow('u1');

    expect(followed.isFollowing, isTrue);
    expect(followed.followersCount, 6);
    expect(unfollowed.isFollowing, isFalse);
    expect(unfollowed.followersCount, 5);
  });

  test('updateProfile sends only provided fields', () async {
    api.responses['PATCH /profile/me'] = _profileJson();

    await repository.updateProfile(firstName: 'Janek', bio: '');

    expect(api.lastBody, {'firstName': 'Janek', 'bio': ''});
  });

  test('uploadAvatar sends multipart field "avatar" with an image type',
      () async {
    api.responses['MULTIPART /profile/me/avatar'] = _profileJson(
      avatarUrl: '/uploads/avatars/new.jpg',
    );

    final profile = await repository.uploadAvatar(
      Uint8List.fromList([1, 2, 3]),
      'blob',
    );

    final file = api.lastFiles!.single;
    expect(file.field, 'avatar');
    expect(file.filename, 'avatar.jpg');
    expect(file.contentType.mimeType, 'image/jpeg');
    expect(profile.avatarUrl, '/uploads/avatars/new.jpg');
  });

  test('removeAvatar returns the profile without avatar', () async {
    api.responses['DELETE /profile/me/avatar'] = _profileJson();

    final profile = await repository.removeAvatar();

    expect(profile.avatarUrl, isNull);
  });

  test('activities parse real kudos/comment counts and hasKudoed', () async {
    api.responses['GET /users/u1/activities?limit=5'] = [
      {
        'id': 'session-1',
        'kind': 'strength',
        'title': 'Push A',
        'date': 'Dziś',
        'duration': '57 min',
        'kudosCount': 3,
        'commentCount': 2,
        'hasKudoed': true,
      },
      {'id': 'session-2', 'title': 'Pull', 'date': 'Wczoraj', 'duration': '1h'},
    ];

    final activities = await repository.getRecentActivities(userId: 'u1');

    expect(activities.first.id, 'session-1');
    expect(activities.first.kudosCount, 3);
    expect(activities.first.commentCount, 2);
    expect(activities.first.hasKudoed, isTrue);
    expect(activities.last.hasKudoed, isFalse);
  });

  test('remembers own avatar URLs per account, not other users', () async {
    api.responses['GET /profile/me'] = _profileJson(
      avatarUrl: '/uploads/avatars/old.jpg',
    );
    api.responses['MULTIPART /profile/me/avatar'] = _profileJson(
      avatarUrl: '/uploads/avatars/new.jpg',
    );
    api.responses['GET /users/u1/profile'] = _profileJson(
      avatarUrl: '/uploads/avatars/seen-as-other.jpg',
    );

    await repository.getOwnProfile();
    await repository.uploadAvatar(Uint8List.fromList([1, 2, 3]), 'a.jpg');
    await repository.getUserProfile('u1');

    expect(repository.ownAvatarUrlsFor('u1'), {
      '/uploads/avatars/old.jpg',
      '/uploads/avatars/new.jpg',
    });
    expect(repository.ownAvatarUrlsFor('other'), isEmpty);
  });
}
