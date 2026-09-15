import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/feed/domain/models/cursor_page.dart';
import 'package:gym/features/feed/domain/models/feed_author.dart';
import 'package:gym/features/feed/domain/models/feed_post.dart';
import 'package:gym/features/feed/domain/models/post_comment.dart';
import 'package:gym/features/feed/domain/models/post_detail.dart';
import 'package:gym/features/feed/domain/repositories/feed_repository.dart';
import 'package:gym/features/feed/domain/services/feed_post_events.dart';
import 'package:gym/features/feed/presentation/bloc/post_comments_cubit.dart';
import 'package:gym/features/feed/presentation/bloc/post_details_cubit.dart';
import 'package:gym/features/profile/domain/models/following_user.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';

class _FakeFeedRepository implements FeedRepository {
  Future<CommentsPage> Function(String? cursor)? onGetComments;
  Future<PostComment> Function(String body)? onAddComment;
  Future<void> Function(String commentId)? onDeleteComment;
  Future<PostDetail> Function()? onGetPost;
  Future<KudosResult> Function(bool give)? onKudos;
  final addCalls = <String>[];
  final deleteCalls = <String>[];

  @override
  Future<CommentsPage> getComments(
    String postId, {
    String? cursor,
    int limit = 30,
  }) => onGetComments!(cursor);

  @override
  Future<PostComment> addComment(String postId, String body) {
    addCalls.add(body);
    return onAddComment!(body);
  }

  @override
  Future<void> deleteComment(String postId, String commentId) {
    deleteCalls.add(commentId);
    return onDeleteComment!(commentId);
  }

  @override
  Future<PostDetail> getPost(String postId) => onGetPost!();

  @override
  Future<KudosResult> giveKudos(String postId) => onKudos!(true);

  @override
  Future<KudosResult> removeKudos(String postId) => onKudos!(false);

  @override
  Future<FeedPage> getFeed({String? cursor, int limit = 20}) =>
      throw UnimplementedError();

  @override
  Future<List<FollowingUser>> getKudos(
    String postId, {
    int limit = 50,
    int offset = 0,
  }) => throw UnimplementedError();

  @override
  Future<List<FollowingUser>> getSuggestedUsers({int limit = 10}) =>
      throw UnimplementedError();
}

const _me = FeedAuthor(id: 'me', firstName: 'Jan', lastName: 'Kowalski');
const _anna = FeedAuthor(id: 'anna', firstName: 'Anna', lastName: 'Nowak');

PostComment _comment(String id, {bool canDelete = true}) => PostComment(
  id: id,
  author: _anna,
  body: 'Komentarz $id',
  createdAt: DateTime.utc(2026, 9, 14, 18),
  canDelete: canDelete,
);

Future<void> _flush() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeFeedRepository repo;
  late FeedPostEvents events;
  late List<FeedPostEvent> received;
  late StreamSubscription<FeedPostEvent> subscription;

  setUp(() {
    repo = _FakeFeedRepository();
    events = FeedPostEvents();
    received = [];
    subscription = events.stream.listen(received.add);
  });

  tearDown(() => subscription.cancel());

  PostCommentsCubit buildComments() => PostCommentsCubit(
    repository: repo,
    postId: 'p1',
    events: events,
    currentUser: _me,
  );

  group('PostCommentsCubit', () {
    test('loads first page and appends newer comments by cursor', () async {
      repo.onGetComments = (cursor) async => cursor == null
          ? CommentsPage(
              items: [_comment('c1'), _comment('c2')],
              nextCursor: 'n1',
              hasMore: true,
            )
          : CommentsPage(items: [_comment('c2'), _comment('c3')]);
      final cubit = buildComments();

      await cubit.load();
      expect(cubit.state.status, PostCommentsStatus.ready);
      expect(cubit.state.hasMore, isTrue);

      await cubit.loadMore();
      expect(cubit.state.items.map((c) => c.id), ['c1', 'c2', 'c3']);
      expect(cubit.state.hasMore, isFalse);
      await cubit.close();
    });

    test('adds a comment optimistically and replaces it with the saved one',
        () async {
      repo.onGetComments = (_) async => CommentsPage(items: [_comment('c1')]);
      final cubit = buildComments();
      await cubit.load();

      final completer = Completer<PostComment>();
      repo.onAddComment = (_) => completer.future;
      final future = cubit.addComment('  Mocny trening!  ');

      expect(cubit.state.isSending, isTrue);
      final pending = cubit.state.items.last;
      expect(pending.isPending, isTrue);
      expect(pending.body, 'Mocny trening!');
      expect(pending.author.id, 'me');
      expect(repo.addCalls, ['Mocny trening!']);

      completer.complete(
        PostComment(
          id: 'c2',
          author: _me,
          body: 'Mocny trening!',
          createdAt: DateTime.utc(2026, 9, 15),
          isOwn: true,
          canDelete: true,
        ),
      );
      expect(await future, isTrue);
      await _flush();

      expect(cubit.state.items.map((c) => c.id), ['c1', 'c2']);
      expect(cubit.state.items.last.isPending, isFalse);
      expect(cubit.state.isSending, isFalse);
      expect(
        received.whereType<PostCommentCountChanged>().single.delta,
        1,
      );
      await cubit.close();
    });

    test('rolls back a failed comment and reports why', () async {
      repo.onGetComments = (_) async => CommentsPage(items: [_comment('c1')]);
      final cubit = buildComments();
      await cubit.load();

      repo.onAddComment = (_) async =>
          throw const ApiException('too_many_requests', statusCode: 429);
      final ok = await cubit.addComment('Hej');

      expect(ok, isFalse);
      expect(cubit.state.items.map((c) => c.id), ['c1']);
      expect(cubit.state.isSending, isFalse);
      expect(cubit.state.notice!.message, contains('zbyt szybko'));
      await _flush();
      expect(received, isEmpty);
      await cubit.close();
    });

    test('rejects blank and too long bodies (500 code points)', () async {
      repo.onGetComments = (_) async => const CommentsPage(items: []);
      repo.onAddComment = (body) async => PostComment(
        id: 'x',
        author: _me,
        body: body,
        createdAt: DateTime.utc(2026),
      );
      final cubit = buildComments();
      await cubit.load();

      expect(await cubit.addComment('   '), isFalse);
      expect(await cubit.addComment('a' * 501), isFalse);
      expect(repo.addCalls, isEmpty);

      // 500 emoji = 500 punktów kodowych (1000 jednostek UTF-16) — dozwolone.
      expect(await cubit.addComment('💪' * 500), isTrue);
      expect(repo.addCalls.length, 1);
      await cubit.close();
    });

    test('deletes a comment and emits a count change', () async {
      repo.onGetComments = (_) async =>
          CommentsPage(items: [_comment('c1'), _comment('c2')]);
      repo.onDeleteComment = (_) async {};
      final cubit = buildComments();
      await cubit.load();

      await cubit.deleteComment('c1');
      await _flush();

      expect(repo.deleteCalls, ['c1']);
      expect(cubit.state.items.map((c) => c.id), ['c2']);
      expect(received.whereType<PostCommentCountChanged>().single.delta, -1);
      await cubit.close();
    });

    test('restores a comment at its position when delete fails', () async {
      repo.onGetComments = (_) async => CommentsPage(
        items: [_comment('c1'), _comment('c2'), _comment('c3')],
      );
      repo.onDeleteComment = (_) async =>
          throw const ApiException('forbidden', statusCode: 403);
      final cubit = buildComments();
      await cubit.load();

      await cubit.deleteComment('c2');

      expect(cubit.state.items.map((c) => c.id), ['c1', 'c2', 'c3']);
      expect(
        cubit.state.notice!.message,
        'Nie możesz usunąć tego komentarza.',
      );
      await cubit.close();
    });

    test('treats comment_not_found as already deleted', () async {
      repo.onGetComments = (_) async => CommentsPage(items: [_comment('c1')]);
      repo.onDeleteComment = (_) async =>
          throw const ApiException('comment_not_found', statusCode: 404);
      final cubit = buildComments();
      await cubit.load();

      await cubit.deleteComment('c1');

      expect(cubit.state.items, isEmpty);
      expect(cubit.state.notice, isNull);
      await cubit.close();
    });
  });

  group('PostDetailsCubit', () {
    PostDetail detail({int kudos = 1, bool hasKudoed = false}) => PostDetail(
      post: FeedPost(
        id: 'p1',
        author: _anna,
        title: 'Push A',
        startedAt: DateTime.utc(2026, 9, 14, 16),
        finishedAt: DateTime.utc(2026, 9, 14, 17),
        durationSec: 3600,
        kudosCount: kudos,
        hasKudoed: hasKudoed,
        commentCount: 2,
      ),
      exercises: const [
        TrainingExerciseDetail(
          exerciseId: 'e1',
          exerciseName: 'Wyciskanie',
          sets: [
            TrainingExerciseSetDetail(
              setIndex: 1,
              actual: TrainingSetMetrics(weightKg: 80, reps: 8),
              completed: true,
            ),
          ],
        ),
      ],
    );

    PostDetailsCubit buildDetails() => PostDetailsCubit(
      repository: repo,
      postId: 'p1',
      events: events,
      currentUser: _me,
    );

    test('loads post and builds session detail for reused widgets', () async {
      repo.onGetPost = () async => detail();
      final cubit = buildDetails();

      await cubit.load();

      expect(cubit.state.status, PostDetailsStatus.ready);
      expect(cubit.state.post!.title, 'Push A');
      expect(cubit.state.sessionDetail!.plan.name, 'Push A');
      expect(cubit.state.sessionDetail!.totalVolumeKg, 640);
      await cubit.close();
    });

    test('maps post_not_found to the not-found state', () async {
      repo.onGetPost = () async =>
          throw const ApiException('post_not_found', statusCode: 404);
      final cubit = buildDetails();

      await cubit.load();

      expect(cubit.state.status, PostDetailsStatus.notFound);
      await cubit.close();
    });

    test('kudos toggle reverts on failure, keeps session detail instance',
        () async {
      repo.onGetPost = () async => detail(kudos: 1);
      final cubit = buildDetails();
      await cubit.load();
      final sessionDetail = cubit.state.sessionDetail;

      final completer = Completer<KudosResult>();
      repo.onKudos = (_) => completer.future;
      final future = cubit.toggleKudos();
      expect(cubit.state.post!.hasKudoed, isTrue);
      expect(cubit.state.post!.kudosCount, 2);

      completer.completeError(const ApiException('network_error'));
      await future;

      expect(cubit.state.post!.hasKudoed, isFalse);
      expect(cubit.state.post!.kudosCount, 1);
      expect(cubit.state.notice!.message, contains('brak połączenia'));
      expect(identical(cubit.state.sessionDetail, sessionDetail), isTrue);
      await cubit.close();
    });

    test('applies comment count changes published by comments cubit',
        () async {
      repo.onGetPost = () async => detail();
      final cubit = buildDetails();
      await cubit.load();

      events.emit(const PostCommentCountChanged('p1', delta: 1));
      await _flush();

      expect(cubit.state.post!.commentCount, 3);
      await cubit.close();
    });
  });
}
