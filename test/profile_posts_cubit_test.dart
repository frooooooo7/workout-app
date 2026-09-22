import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/feed/domain/models/cursor_page.dart';
import 'package:gym/features/feed/domain/models/feed_author.dart';
import 'package:gym/features/feed/domain/models/feed_post.dart';
import 'package:gym/features/feed/domain/models/post_detail.dart';
import 'package:gym/features/feed/domain/repositories/feed_repository.dart';
import 'package:gym/features/feed/domain/services/feed_post_events.dart';
import 'package:gym/features/profile/presentation/bloc/profile_posts_cubit.dart';
import 'package:gym/features/profile/presentation/bloc/profile_posts_state.dart';

const _anna = FeedAuthor(id: 'anna', firstName: 'Anna', lastName: 'Nowak');

FeedPost _post(String id, {bool isOwn = false, int kudos = 0}) => FeedPost(
  id: id,
  author: _anna,
  title: 'Trening $id',
  startedAt: DateTime(2026, 9, 20),
  isOwn: isOwn,
  kudosCount: kudos,
);

class _Repo extends Fake implements FeedRepository {
  bool offline = false;
  bool failKudos = false;
  final pages = <String?, FeedPage>{};
  final cursors = <String?>[];

  @override
  Future<FeedPage> getUserPosts(
    String userId, {
    String? cursor,
    int limit = 10,
  }) async {
    cursors.add(cursor);
    if (offline) throw const ApiException('network_error');
    return pages[cursor] ?? const FeedPage(items: []);
  }

  @override
  Future<KudosResult> giveKudos(String postId) async {
    if (failKudos) throw const ApiException('network_error');
    return const KudosResult(hasKudoed: true, kudosCount: 4);
  }
}

void main() {
  test('posts of workouts deleted offline are hidden', () async {
    final repo = _Repo()
      ..pages[null] = FeedPage(items: [_post('a'), _post('b')]);
    final hidden = <String>{'a'};
    final cubit = ProfilePostsCubit(
      repository: repo,
      userId: 'anna',
      hiddenPostIds: () async => hidden,
    );

    await cubit.load();
    expect(cubit.state.items.map((p) => p.id), ['b']);

    // Usunięcie offline: odświeżenie bez sieci i tak chowa aktywność.
    hidden.add('b');
    repo.offline = true;
    await cubit.refresh();

    expect(cubit.state.items, isEmpty);
    await cubit.close();
  });

  test('first load failure offline is reported as offline', () async {
    final repo = _Repo()..offline = true;
    final cubit = ProfilePostsCubit(repository: repo, userId: 'anna');

    await cubit.load();

    expect(cubit.state.status, ProfilePostsStatus.failure);
    expect(cubit.state.offline, isTrue);
    await cubit.close();
  });

  test('loadMore appends the next page by cursor without duplicates', () async {
    final repo = _Repo()
      ..pages[null] = FeedPage(
        items: [_post('a'), _post('b')],
        nextCursor: 'c1',
        hasMore: true,
      )
      ..pages['c1'] = FeedPage(items: [_post('b'), _post('c')]);
    final cubit = ProfilePostsCubit(repository: repo, userId: 'anna');

    await cubit.load();
    await cubit.loadMore();

    expect(cubit.state.items.map((p) => p.id), ['a', 'b', 'c']);
    expect(cubit.state.hasMore, isFalse);
    expect(repo.cursors, [null, 'c1']);
    await cubit.close();
  });

  test('kudos is optimistic, confirmed by server and broadcast', () async {
    final events = FeedPostEvents();
    final received = <FeedPostEvent>[];
    final sub = events.stream.listen(received.add);
    final repo = _Repo()..pages[null] = FeedPage(items: [_post('a', kudos: 3)]);
    final cubit = ProfilePostsCubit(
      repository: repo,
      userId: 'anna',
      events: events,
    );
    await cubit.load();

    await cubit.toggleKudos('a');
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.items.single.hasKudoed, isTrue);
    expect(cubit.state.items.single.kudosCount, 4);
    expect(received.single, isA<PostKudosChanged>());
    await sub.cancel();
    await cubit.close();
  });

  test('failed kudos rolls back and shows a notice', () async {
    final repo = _Repo()
      ..failKudos = true
      ..pages[null] = FeedPage(items: [_post('a', kudos: 3)]);
    final cubit = ProfilePostsCubit(repository: repo, userId: 'anna');
    await cubit.load();

    await cubit.toggleKudos('a');

    expect(cubit.state.items.single.hasKudoed, isFalse);
    expect(cubit.state.items.single.kudosCount, 3);
    expect(cubit.state.notice, isNotNull);
    await cubit.close();
  });

  test('own posts cannot be kudoed', () async {
    final repo = _Repo()
      ..pages[null] = FeedPage(items: [_post('a', isOwn: true)]);
    final cubit = ProfilePostsCubit(repository: repo, userId: 'me');
    await cubit.load();

    await cubit.toggleKudos('a');

    expect(cubit.state.items.single.hasKudoed, isFalse);
    await cubit.close();
  });

  test('comment events from post details update the counter', () async {
    final events = FeedPostEvents();
    final repo = _Repo()..pages[null] = FeedPage(items: [_post('a')]);
    final cubit = ProfilePostsCubit(
      repository: repo,
      userId: 'anna',
      events: events,
    );
    await cubit.load();

    events.emit(const PostCommentCountChanged('a', delta: 1));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.items.single.commentCount, 1);
    await cubit.close();
  });
}
