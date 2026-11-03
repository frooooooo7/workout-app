import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/feed/domain/models/cursor_page.dart';
import 'package:gym/features/feed/domain/models/feed_author.dart';
import 'package:gym/features/feed/domain/models/feed_post.dart';
import 'package:gym/features/feed/domain/models/post_comment.dart';
import 'package:gym/features/feed/domain/models/post_detail.dart';
import 'package:gym/features/library/domain/models/exercise.dart';
import 'package:gym/features/feed/domain/repositories/feed_repository.dart';
import 'package:gym/features/feed/presentation/bloc/post_comments_cubit.dart';
import 'package:gym/features/feed/presentation/bloc/post_details_cubit.dart';
import 'package:gym/features/feed/presentation/screens/post_details_screen.dart';
import 'package:gym/features/feed/presentation/widgets/comment_input_bar.dart';
import 'package:gym/features/profile/domain/models/following_user.dart';
import 'package:gym/features/profile/domain/repositories/profile_repository.dart';
import 'package:gym/features/profile/presentation/bloc/follow_cubit.dart';
import 'package:gym/features/training/domain/models/training_history_models.dart';

class _NoOpProfileRepository extends Fake implements ProfileRepository {}

const _anna = FeedAuthor(id: 'anna', firstName: 'Anna', lastName: 'Nowak');

class _FakeFeedRepository implements FeedRepository {
  _FakeFeedRepository({
    required this.exercises,
    this.kudos = 0,
    this.commentsGate,
  });

  final int exercises;
  final int kudos;

  /// Wstrzymuje odpowiedź z komentarzami do czasu ukończenia.
  final Completer<void>? commentsGate;

  @override
  Future<PostDetail> getPost(String postId) async => PostDetail(
    post: FeedPost(
      id: 'p1',
      author: _anna,
      title: 'Push A',
      startedAt: DateTime(2026, 9, 15, 18, 5),
      durationSec: 3420,
      exercisesCount: exercises,
      completedSetsCount: exercises * 3,
      totalVolumeKg: 5230.5,
      muscles: const [MuscleGroup.chest],
      topExercises: const [],
      personalRecords: const [],
      kudosCount: kudos,
      commentCount: 2,
      hasKudoed: false,
      isOwn: false,
      recentKudos: const [],
    ),
    exercises: [
      for (var i = 0; i < exercises; i++)
        TrainingExerciseDetail(
          exerciseId: 'e$i',
          exerciseName: 'Ćwiczenie $i',
          muscles: const [MuscleGroup.chest],
          sets: [
            for (var s = 0; s < 3; s++)
              TrainingExerciseSetDetail(
                setIndex: s,
                actual: const TrainingSetMetrics(weightKg: 60, reps: 8),
                completed: true,
              ),
          ],
        ),
    ],
  );

  @override
  Future<CommentsPage> getComments(
    String postId, {
    String? cursor,
    int limit = 30,
  }) async {
    await commentsGate?.future;
    return CommentsPage(
      items: [
        for (var i = 0; i < 2; i++)
          PostComment(
            id: 'c$i',
            author: _anna,
            body: 'Komentarz $i',
            createdAt: DateTime.utc(2026, 9, 14, 18),
          ),
      ],
    );
  }

  @override
  Future<FeedPage> getFeed({String? cursor, int limit = 20}) =>
      throw UnimplementedError();

  @override
  Future<FeedPage> getUserPosts(
    String userId, {
    String? cursor,
    int limit = 10,
  }) => throw UnimplementedError();

  @override
  Future<KudosResult> giveKudos(String postId) => throw UnimplementedError();

  @override
  Future<KudosResult> removeKudos(String postId) => throw UnimplementedError();

  @override
  Future<List<FollowingUser>> getKudos(
    String postId, {
    int limit = 50,
    int offset = 0,
  }) => throw UnimplementedError();

  @override
  Future<PostComment> addComment(String postId, String body) =>
      throw UnimplementedError();

  @override
  Future<void> deleteComment(String postId, String commentId) =>
      throw UnimplementedError();

  @override
  Future<List<FollowingUser>> getSuggestedUsers({int limit = 10}) =>
      throw UnimplementedError();
}

Future<void> _pump(
  WidgetTester tester, {
  required bool focusComment,
  int exercises = 14,
  int kudos = 0,
  double width = 412,
  Completer<void>? commentsGate,
}) async {
  tester.view.physicalSize = Size(width, _screenHeight);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _FakeFeedRepository(
    exercises: exercises,
    kudos: kudos,
    commentsGate: commentsGate,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => PostDetailsCubit(repository: repo, postId: 'p1'),
          ),
          BlocProvider(
            create: (_) => PostCommentsCubit(repository: repo, postId: 'p1'),
          ),
          BlocProvider(create: (_) => FollowCubit(_NoOpProfileRepository())),
        ],
        child: PostDetailsScreen(
          postId: 'p1',
          repository: repo,
          focusComment: focusComment,
        ),
      ),
    ),
  );
  if (commentsGate == null) {
    await tester.pumpAndSettle();
  } else {
    // Spinner komentarzy animuje się w nieskończoność — pumpAndSettle by nie
    // skończył.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
}

const _screenHeight = 892.0;

void main() {
  testWidgets('focusComment scrolls a long post down to the comments', (
    tester,
  ) async {
    await _pump(tester, focusComment: true);

    final title = find.text('Komentarze (2)');
    expect(title, findsOneWidget);
    final top = tester.getTopLeft(title).dy;
    expect(top, greaterThanOrEqualTo(0));
    expect(top, lessThan(892));
    expect(find.text('Komentarz 0'), findsOneWidget);
    // Pole komentarza dostaje fokus po przewinięciu.
    final input = tester.widget<CommentInputBar>(find.byType(CommentInputBar));
    expect(input.focusNode!.hasFocus, isTrue);
  });

  testWidgets('without focusComment the post opens at the top', (tester) async {
    await _pump(tester, focusComment: false);

    expect(find.text('Komentarze (2)'), findsNothing);
    expect(find.text('Push A'), findsWidgets);
  });

  testWidgets('keyboard does not cover the comments', (tester) async {
    await _pump(tester, focusComment: true);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    final visibleBottom = _screenHeight - 320;
    for (final text in ['Komentarze (2)', 'Komentarz 0', 'Komentarz 1']) {
      final rect = tester.getRect(find.text(text));
      expect(rect.top, greaterThanOrEqualTo(0), reason: text);
      expect(rect.bottom, lessThanOrEqualTo(visibleBottom), reason: text);
    }
  });

  testWidgets('comments that load later are scrolled into view', (
    tester,
  ) async {
    final gate = Completer<void>();
    await _pump(tester, focusComment: true, commentsGate: gate);
    expect(find.text('Komentarz 1'), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.text('Komentarz 1'));
    expect(rect.bottom, lessThanOrEqualTo(_screenHeight));
    expect(rect.top, greaterThanOrEqualTo(0));
  });

  testWidgets('scrolling by hand stops the automatic scroll', (tester) async {
    final gate = Completer<void>();
    await _pump(tester, focusComment: true, commentsGate: gate);
    final list = find.byType(ListView);
    await tester.drag(list, const Offset(0, 500));
    await tester.pump(const Duration(seconds: 1));
    final controller = tester.widget<ListView>(list).controller!;
    final offset = controller.offset;

    gate.complete();
    await tester.pumpAndSettle();

    expect(controller.offset, offset);
  });

  testWidgets('tapping the comment count scrolls without the keyboard', (
    tester,
  ) async {
    // Szerszy ekran: testowa czcionka (Ahem) jest dużo szersza od prawdziwej.
    await _pump(tester, focusComment: false, kudos: 2, width: 700);
    expect(find.text('Komentarze (2)'), findsNothing);

    await tester.tap(find.text('2 komentarze'));
    await tester.pumpAndSettle();

    expect(find.text('Komentarze (2)'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Komentarze (2)')).dy, lessThan(892));
    final input = tester.widget<CommentInputBar>(find.byType(CommentInputBar));
    expect(input.focusNode!.hasFocus, isFalse);
  });
}
