import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/feed/domain/models/cursor_page.dart';
import 'package:gym/features/feed/domain/models/feed_author.dart';
import 'package:gym/features/feed/domain/models/feed_post.dart';
import 'package:gym/features/feed/domain/models/post_comment.dart';
import 'package:gym/features/feed/domain/models/post_detail.dart';
import 'package:gym/features/feed/domain/repositories/feed_repository.dart';
import 'package:gym/features/feed/domain/services/feed_post_events.dart';
import 'package:gym/features/feed/presentation/bloc/feed_cubit.dart';
import 'package:gym/features/feed/presentation/bloc/feed_state.dart';
import 'package:gym/features/profile/domain/models/following_user.dart';

class _FakeFeedRepository implements FeedRepository {
  @override
  Future<FeedPage> getUserPosts(
    String userId, {
    String? cursor,
    int limit = 10,
  }) async => const FeedPage(items: []);

  final feedCalls = <String?>[];
  final kudosCalls = <String>[];
  late Future<FeedPage> Function(String? cursor) onGetFeed;
  Future<KudosResult> Function(String postId, bool give)? onKudos;
  List<FollowingUser> suggestions = const [];
  int suggestionCalls = 0;

  @override
  Future<FeedPage> getFeed({String? cursor, int limit = 20}) {
    feedCalls.add(cursor);
    return onGetFeed(cursor);
  }

  @override
  Future<KudosResult> giveKudos(String postId) {
    kudosCalls.add('give $postId');
    return onKudos!(postId, true);
  }

  @override
  Future<KudosResult> removeKudos(String postId) {
    kudosCalls.add('remove $postId');
    return onKudos!(postId, false);
  }

  @override
  Future<List<FollowingUser>> getSuggestedUsers({int limit = 10}) async {
    suggestionCalls++;
    return suggestions;
  }

  @override
  Future<PostComment> addComment(String postId, String body) =>
      throw UnimplementedError();

  @override
  Future<void> deleteComment(String postId, String commentId) =>
      throw UnimplementedError();

  @override
  Future<CommentsPage> getComments(
    String postId, {
    String? cursor,
    int limit = 30,
  }) => throw UnimplementedError();

  @override
  Future<List<FollowingUser>> getKudos(
    String postId, {
    int limit = 50,
    int offset = 0,
  }) => throw UnimplementedError();

  @override
  Future<PostDetail> getPost(String postId) => throw UnimplementedError();
}

class _MemoryFeedCache implements FeedCache {
  FeedPage? page;
  final writes = <FeedPage>[];

  @override
  Future<FeedPage?> read(String userId) async => page;

  @override
  Future<void> write(String userId, FeedPage page) async {
    this.page = page;
    writes.add(page);
  }
}

const _me = FeedAuthor(id: 'me', firstName: 'Jan', lastName: 'Kowalski');

FeedPost _post(
  String id, {
  bool hasKudoed = false,
  int kudos = 0,
  int comments = 0,
  bool isOwn = false,
}) {
  return FeedPost(
    id: id,
    author: FeedAuthor(id: 'author-$id', firstName: 'Anna', lastName: 'Nowak'),
    title: 'Push $id',
    startedAt: DateTime.utc(2026, 9, 14, 16),
    kudosCount: kudos,
    commentCount: comments,
    hasKudoed: hasKudoed,
    isOwn: isOwn,
  );
}

FeedPage _page(List<FeedPost> items, {String? cursor, bool hasMore = false}) =>
    FeedPage(items: items, nextCursor: cursor, hasMore: hasMore);

Future<void> _flush() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeFeedRepository repo;
  late _MemoryFeedCache cache;

  FeedCubit buildCubit({
    Listenable? refreshSignal,
    FeedPostEvents? events,
    HiddenPostIds? hiddenPostIds,
  }) {
    return FeedCubit(
      repository: repo,
      cache: cache,
      userId: 'me',
      refreshSignal: refreshSignal,
      events: events,
      currentUser: _me,
      hiddenPostIds: hiddenPostIds,
    );
  }

  setUp(() {
    repo = _FakeFeedRepository();
    cache = _MemoryFeedCache();
  });

  group('first load', () {
    test('loads first page, stores it in cache', () async {
      repo.onGetFeed = (_) async =>
          _page([_post('p1'), _post('p2')], cursor: 'c1', hasMore: true);
      final cubit = buildCubit();

      await cubit.load();

      expect(cubit.state.status, FeedStatus.ready);
      expect(cubit.state.items.map((p) => p.id), ['p1', 'p2']);
      expect(cubit.state.nextCursor, 'c1');
      expect(cubit.state.hasMore, isTrue);
      await _flush();
      expect(cache.page!.items.map((p) => p.id), ['p1', 'p2']);
      expect(repo.suggestionCalls, 0);
      await cubit.close();
    });

    test('shows cached page immediately, then replaces it with fresh data',
        () async {
      cache.page = _page([_post('cached')]);
      final completer = Completer<FeedPage>();
      repo.onGetFeed = (_) => completer.future;
      final cubit = buildCubit();

      final loading = cubit.load();
      await _flush();

      expect(cubit.state.status, FeedStatus.ready);
      expect(cubit.state.items.single.id, 'cached');
      expect(cubit.state.isRefreshing, isTrue);

      completer.complete(_page([_post('fresh')]));
      await loading;

      expect(cubit.state.items.single.id, 'fresh');
      expect(cubit.state.isRefreshing, isFalse);
      expect(cubit.state.staleMessage, isNull);
      await cubit.close();
    });

    test('keeps cached page with offline banner when network fails', () async {
      cache.page = _page([_post('cached')]);
      repo.onGetFeed = (_) async => throw const ApiException('network_error');
      final cubit = buildCubit();

      await cubit.load();

      expect(cubit.state.status, FeedStatus.ready);
      expect(cubit.state.items.single.id, 'cached');
      expect(
        cubit.state.staleMessage,
        'Brak połączenia — pokazuję zapisany feed',
      );
      await cubit.close();
    });

    test('shows full error without cache, retry recovers', () async {
      repo.onGetFeed = (_) async => throw const ApiException('network_error');
      final cubit = buildCubit();

      await cubit.load();
      expect(cubit.state.status, FeedStatus.failure);
      expect(cubit.state.errorMessage, contains('Brak połączenia'));

      repo.onGetFeed = (_) async => _page([_post('p1')]);
      await cubit.refresh();
      expect(cubit.state.status, FeedStatus.ready);
      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.items.single.id, 'p1');
      await cubit.close();
    });

    test('empty feed loads suggested users', () async {
      repo.onGetFeed = (_) async => _page(const []);
      repo.suggestions = const [
        FollowingUser(id: 'u1', firstName: 'Ola', lastName: 'Lis', handle: 'ola'),
      ];
      final cubit = buildCubit();

      await cubit.load();
      await _flush();

      expect(cubit.state.isEmptyFeed, isTrue);
      expect(cubit.state.suggestions.single.id, 'u1');
      expect(cubit.state.suggestionsLoaded, isTrue);
      await cubit.close();
    });
  });

  group('refresh', () {
    test('replaces items and shares one request for concurrent calls',
        () async {
      repo.onGetFeed = (_) async => _page([_post('p1')]);
      final cubit = buildCubit();
      await cubit.load();

      final completer = Completer<FeedPage>();
      repo.onGetFeed = (_) => completer.future;
      final a = cubit.refresh();
      final b = cubit.refresh();
      completer.complete(_page([_post('p0'), _post('p1')]));
      await Future.wait([a, b]);

      expect(repo.feedCalls, [null, null]);
      expect(cubit.state.items.map((p) => p.id), ['p0', 'p1']);
      await cubit.close();
    });

    test('refresh signal (share / follow) reloads the feed', () async {
      final signal = ValueNotifier(0);
      repo.onGetFeed = (_) async => _page([_post('p1')]);
      final cubit = buildCubit(refreshSignal: signal);
      await cubit.load();

      repo.onGetFeed = (_) async => _page([_post('shared'), _post('p1')]);
      signal.value++;
      await _flush();

      expect(repo.feedCalls.length, 2);
      expect(cubit.state.items.first.id, 'shared');
      await cubit.close();
    });
  });

  group('pagination', () {
    test('appends next page once, deduplicates and stops at the end',
        () async {
      repo.onGetFeed = (_) async =>
          _page([_post('p1'), _post('p2')], cursor: 'c1', hasMore: true);
      final cubit = buildCubit();
      await cubit.load();

      final completer = Completer<FeedPage>();
      repo.onGetFeed = (_) => completer.future;
      final first = cubit.loadMore();
      final second = cubit.loadMore();
      expect(cubit.state.isLoadingMore, isTrue);

      completer.complete(_page([_post('p2'), _post('p3')]));
      await Future.wait([first, second]);

      expect(repo.feedCalls, [null, 'c1']);
      expect(cubit.state.items.map((p) => p.id), ['p1', 'p2', 'p3']);
      expect(cubit.state.hasMore, isFalse);
      expect(cubit.state.isLoadingMore, isFalse);

      await cubit.loadMore();
      expect(repo.feedCalls.length, 2);
      await cubit.close();
    });

    test('failed page shows retry state; invalid cursor refreshes', () async {
      repo.onGetFeed = (_) async =>
          _page([_post('p1')], cursor: 'c1', hasMore: true);
      final cubit = buildCubit();
      await cubit.load();

      repo.onGetFeed = (_) async => throw const ApiException('network_error');
      await cubit.loadMore();
      expect(cubit.state.loadMoreFailed, isTrue);
      expect(cubit.state.items.length, 1);

      repo.onGetFeed = (cursor) async => cursor == null
          ? _page([_post('new')])
          : throw const ApiException('invalid_cursor', statusCode: 400);
      await cubit.loadMore();
      expect(cubit.state.items.single.id, 'new');
      expect(cubit.state.loadMoreFailed, isFalse);
      await cubit.close();
    });
  });

  group('kudos', () {
    test('toggles optimistically, applies server count and emits event',
        () async {
      final events = FeedPostEvents();
      final received = <FeedPostEvent>[];
      final sub = events.stream.listen(received.add);
      repo.onGetFeed = (_) async => _page([_post('p1', kudos: 2)]);
      final cubit = buildCubit(events: events);
      await cubit.load();

      final completer = Completer<KudosResult>();
      repo.onKudos = (_, _) => completer.future;
      final future = cubit.toggleKudos('p1');

      var post = cubit.state.items.single;
      expect(post.hasKudoed, isTrue);
      expect(post.kudosCount, 3);
      expect(post.recentKudos.first.id, 'me');

      // Drugi tap w trakcie żądania jest ignorowany.
      await cubit.toggleKudos('p1');
      expect(repo.kudosCalls, ['give p1']);

      completer.complete(const KudosResult(hasKudoed: true, kudosCount: 5));
      await future;
      await _flush();

      post = cubit.state.items.single;
      expect(post.kudosCount, 5);
      expect(post.hasKudoed, isTrue);
      expect(received.whereType<PostKudosChanged>().single.kudosCount, 5);
      await sub.cancel();
      await cubit.close();
    });

    test('reverts and reports a Polish message on failure', () async {
      repo.onGetFeed = (_) async =>
          _page([_post('p1', kudos: 4, hasKudoed: true)]);
      final cubit = buildCubit();
      await cubit.load();

      repo.onKudos = (_, _) async => throw const ApiException('network_error');
      await cubit.toggleKudos('p1');

      final post = cubit.state.items.single;
      expect(repo.kudosCalls, ['remove p1']);
      expect(post.hasKudoed, isTrue);
      expect(post.kudosCount, 4);
      expect(cubit.state.notice!.message, contains('brak połączenia'));
      await cubit.close();
    });

    test('own posts cannot be kudoed', () async {
      repo.onGetFeed = (_) async => _page([_post('p1', isOwn: true)]);
      final cubit = buildCubit();
      await cubit.load();

      await cubit.toggleKudos('p1');

      expect(repo.kudosCalls, isEmpty);
      expect(cubit.state.items.single.hasKudoed, isFalse);
      await cubit.close();
    });
  });

  test('comment count events from post details update the list', () async {
    final events = FeedPostEvents();
    repo.onGetFeed = (_) async => _page([_post('p1', comments: 1)]);
    final cubit = buildCubit(events: events);
    await cubit.load();

    events.emit(const PostCommentCountChanged('p1', delta: 1));
    await _flush();

    expect(cubit.state.items.single.commentCount, 2);
    await cubit.close();
  });

  group('workouts deleted offline (pending delete)', () {
    test('are filtered from fetched pages and the cached page', () async {
      cache.page = _page([_post('gone'), _post('cached')]);
      final completer = Completer<FeedPage>();
      repo.onGetFeed = (_) => completer.future;
      final cubit = buildCubit(hiddenPostIds: () async => {'gone'});

      final loading = cubit.load();
      await _flush();
      expect(cubit.state.items.map((p) => p.id), ['cached']);

      completer.complete(_page([_post('gone'), _post('p1')]));
      await loading;
      expect(cubit.state.items.map((p) => p.id), ['p1']);
      await cubit.close();
    });

    test('disappear on refresh signal even when offline', () async {
      final signal = ValueNotifier(0);
      final hidden = <String>{};
      repo.onGetFeed = (_) async => _page([_post('p1'), _post('p2')]);
      final cubit = buildCubit(
        refreshSignal: signal,
        hiddenPostIds: () async => hidden,
      );
      await cubit.load();

      hidden.add('p1');
      repo.onGetFeed = (_) async => throw const ApiException('network_error');
      signal.value++;
      await _flush();

      expect(cubit.state.items.map((p) => p.id), ['p2']);
      expect(cubit.state.staleMessage, isNotNull);
      expect(cache.page!.items.map((p) => p.id), ['p2']);
      await cubit.close();
    });
  });
}
