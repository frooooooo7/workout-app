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
  _FakeFeedRepository({required this.exercises});

  final int exercises;

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
      kudosCount: 0,
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
  }) async => CommentsPage(
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
}) async {
  tester.view.physicalSize = const Size(412, 892);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = _FakeFeedRepository(exercises: exercises);
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
  await tester.pumpAndSettle();
}

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
}
