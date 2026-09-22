import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/feed/data/api_feed_repository.dart';
import 'package:gym/features/feed/data/feed_json.dart';
import 'package:gym/features/library/domain/models/exercise.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://test.local');

  final calls = <String>[];
  final responses = <String, dynamic>{};
  Map<String, dynamic>? lastBody;

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
  Future<dynamic> delete(String path, {bool auth = false}) async =>
      _respond('DELETE', path);
}

Map<String, dynamic> _author(String id) => {
  'id': id,
  'firstName': 'Anna',
  'lastName': 'Nowak',
  'handle': 'anna',
  'avatarUrl': '/uploads/avatars/$id.jpg',
};

Map<String, dynamic> _postJson({String id = 'p1'}) => {
  'id': id,
  'author': _author('u1'),
  'title': 'Push A',
  'note': '  Dobra sesja  ',
  'startedAt': '2026-09-14T16:00:00.000Z',
  'finishedAt': '2026-09-14T16:57:00.000Z',
  'durationSec': 3420,
  'exercisesCount': 6,
  'completedSetsCount': 18,
  'totalVolumeKg': 5230.5,
  'muscles': ['chest', 'triceps', 'unknown_muscle'],
  'topExercises': [
    {
      'name': 'Wyciskanie sztangi na ławce',
      'completedSets': 4,
      'bestSet': {'weightKg': 82.5, 'reps': 8},
    },
    {'name': 'Pompki', 'completedSets': 3, 'bestSet': null},
  ],
  'kudosCount': 3,
  'commentCount': 1,
  'hasKudoed': true,
  'isOwn': false,
  'recentKudos': [_author('u2')],
};

void main() {
  late _FakeApiClient api;
  late ApiFeedRepository repository;

  setUp(() {
    api = _FakeApiClient();
    repository = ApiFeedRepository(api);
  });

  test('getFeed parses posts, cursor and skips malformed items', () async {
    api.responses['GET /feed?limit=20&cursor=abc'] = {
      'items': [
        _postJson(),
        {'id': 'broken'},
      ],
      'nextCursor': 'next',
      'hasMore': true,
    };

    final page = await repository.getFeed(cursor: 'abc');

    expect(page.nextCursor, 'next');
    expect(page.hasMore, isTrue);
    final post = page.items.single;
    expect(post.author.fullName, 'Anna Nowak');
    expect(post.author.avatarUrl, '/uploads/avatars/u1.jpg');
    expect(post.note, 'Dobra sesja');
    expect(post.startedAt, DateTime.utc(2026, 9, 14, 16));
    expect(post.totalVolumeKg, 5230.5);
    expect(post.muscles, [MuscleGroup.chest, MuscleGroup.triceps]);
    expect(post.topExercises.first.bestSet!.weightKg, 82.5);
    expect(post.topExercises.first.bestSet!.reps, 8);
    expect(post.topExercises.last.bestSet, isNull);
    expect(post.hasKudoed, isTrue);
    expect(post.recentKudos.single.id, 'u2');
  });

  test('getUserPosts hits the profile timeline with cursor', () async {
    api.responses['GET /users/u1/posts?limit=10&cursor=abc'] = {
      'items': [_postJson()],
      'nextCursor': 'next',
      'hasMore': true,
    };

    final page = await repository.getUserPosts('u1', cursor: 'abc');

    expect(api.calls, ['GET /users/u1/posts?limit=10&cursor=abc']);
    expect(page.items.single.title, isNotEmpty);
    expect(page.nextCursor, 'next');
    expect(page.hasMore, isTrue);
  });

  test('first page path has no cursor', () async {
    api.responses['GET /feed?limit=20'] = {
      'items': <dynamic>[],
      'nextCursor': null,
      'hasMore': false,
    };

    final page = await repository.getFeed();

    expect(api.calls, ['GET /feed?limit=20']);
    expect(page.items, isEmpty);
  });

  test('getPost parses exercises with exerciseMuscles and completedAt',
      () async {
    api.responses['GET /posts/p1'] = {
      ..._postJson(),
      'exercises': [
        {
          'exerciseId': null,
          'exerciseName': 'Wyciskanie sztangi na ławce',
          'exerciseMuscles': ['chest', 'triceps'],
          'exerciseCategory': 'compound',
          'imageUrl': null,
          'sets': [
            {
              'setIndex': 1,
              'planned': {'weightKg': 80, 'reps': 8, 'rir': 2, 'tempo': null},
              'actual': {'weightKg': 82.5, 'reps': 8, 'rir': 1, 'tempo': null},
              'completed': true,
              'completedAt': '2026-09-14T16:10:00.000Z',
            },
            {
              'setIndex': 2,
              'planned': {'weightKg': 80, 'reps': 8, 'rir': null, 'tempo': null},
              'actual': {'weightKg': null, 'reps': null, 'rir': null, 'tempo': null},
              'completed': false,
              'completedAt': null,
            },
          ],
        },
      ],
    };

    final detail = await repository.getPost('p1');

    final exercise = detail.exercises.single;
    expect(exercise.exerciseId, '');
    expect(exercise.muscles, [MuscleGroup.chest, MuscleGroup.triceps]);
    expect(exercise.sets.first.actual!.weightKg, 82.5);
    expect(exercise.sets.first.completedAt, DateTime.utc(2026, 9, 14, 16, 10));
    expect(exercise.completedSetsCount, 1);
    final session = detail.toSessionDetail();
    expect(session.totalVolumeKg, 660);
    expect(session.durationSec, 3420);
    expect(session.note, 'Dobra sesja');
  });

  test('kudos endpoints use POST/DELETE and parse the result', () async {
    api.responses['POST /posts/p1/kudos'] = {
      'hasKudoed': true,
      'kudosCount': 4,
    };
    api.responses['DELETE /posts/p1/kudos'] = {
      'hasKudoed': false,
      'kudosCount': 3,
    };

    final given = await repository.giveKudos('p1');
    final removed = await repository.removeKudos('p1');

    expect(given.hasKudoed, isTrue);
    expect(given.kudosCount, 4);
    expect(removed.hasKudoed, isFalse);
    expect(removed.kudosCount, 3);
  });

  test('invalid kudos response throws', () async {
    api.responses['POST /posts/p1/kudos'] = {'ok': true};

    expect(
      () => repository.giveKudos('p1'),
      throwsA(isA<ApiException>()),
    );
  });

  test('comments: list, add with body, delete path', () async {
    api.responses['GET /posts/p1/comments?limit=30'] = {
      'items': [
        {
          'id': 'c1',
          'author': _author('u3'),
          'body': 'Mocno!',
          'createdAt': '2026-09-14T18:00:00.000Z',
          'isOwn': false,
          'canDelete': true,
        },
      ],
      'nextCursor': null,
      'hasMore': false,
    };
    api.responses['POST /posts/p1/comments'] = {
      'id': 'c2',
      'author': _author('me'),
      'body': 'Dzięki',
      'createdAt': '2026-09-14T18:05:00.000Z',
      'isOwn': true,
      'canDelete': true,
    };

    final page = await repository.getComments('p1');
    final added = await repository.addComment('p1', 'Dzięki');
    await repository.deleteComment('p1', 'c2');

    expect(page.items.single.body, 'Mocno!');
    expect(page.items.single.canDelete, isTrue);
    expect(api.lastBody, {'body': 'Dzięki'});
    expect(added.isOwn, isTrue);
    expect(api.calls.last, 'DELETE /posts/p1/comments/c2');
  });

  test('kudos list and suggestions parse into FollowingUser', () async {
    final user = {..._author('u5'), 'isFollowing': true};
    api.responses['GET /posts/p1/kudos?limit=50&offset=0'] = [user];
    api.responses['GET /users/suggested?limit=10'] = [
      {..._author('u6'), 'isFollowing': false},
    ];

    final kudos = await repository.getKudos('p1');
    final suggested = await repository.getSuggestedUsers();

    expect(kudos.single.isFollowing, isTrue);
    expect(suggested.single.id, 'u6');
  });

  test('feed page survives cache round trip', () {
    final page = FeedJson.feedPageFromJson({
      'items': [_postJson()],
      'nextCursor': 'n',
      'hasMore': true,
    });

    final restored = FeedJson.feedPageFromJson(
      jsonDecode(jsonEncode(FeedJson.feedPageToJson(page))),
    );

    final post = restored.items.single;
    expect(restored.nextCursor, 'n');
    expect(post.title, 'Push A');
    expect(post.muscles, [MuscleGroup.chest, MuscleGroup.triceps]);
    expect(post.topExercises.first.bestSet!.weightKg, 82.5);
    expect(post.recentKudos.single.id, 'u2');
    expect(post.startedAt, DateTime.utc(2026, 9, 14, 16));
  });
}
