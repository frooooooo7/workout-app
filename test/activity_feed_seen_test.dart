import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/feed/domain/models/cursor_page.dart';
import 'package:gym/features/feed/domain/models/feed_author.dart';
import 'package:gym/features/feed/domain/models/feed_post.dart';
import 'package:gym/features/feed/domain/repositories/feed_repository.dart';
import 'package:gym/features/feed/presentation/bloc/feed_cubit.dart';
import 'package:gym/features/feed/presentation/screens/activity_feed_screen.dart';
import 'package:gym/features/feed/presentation/widgets/feed_seen_markers.dart';
import 'package:gym/features/profile/domain/models/following_user.dart';
import 'package:gym/features/profile/domain/repositories/profile_repository.dart';
import 'package:gym/features/profile/presentation/bloc/follow_cubit.dart';

class _NoOpProfileRepository extends Fake implements ProfileRepository {}

class _FakeFeedRepository extends Fake implements FeedRepository {
  _FakeFeedRepository(this.posts);

  final List<FeedPost> posts;

  @override
  Future<FeedPage> getFeed({String? cursor, int limit = 20}) async =>
      FeedPage(items: posts);

  @override
  Future<List<FollowingUser>> getSuggestedUsers({int limit = 10}) async =>
      const [];
}

class _SeenStore implements FeedSeenStore {
  _SeenStore(this.ids);

  List<String>? ids;

  @override
  Future<List<String>?> read(String userId) async => ids;

  @override
  Future<void> write(String userId, List<String> postIds) async =>
      ids = postIds;
}

FeedPost _post(String id) => FeedPost(
      id: id,
      author: FeedAuthor(id: 'a-$id', firstName: 'Anna', lastName: id),
      title: 'Trening $id',
      startedAt: DateTime(2026, 9, 20, 10),
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<FeedPost> posts,
  required List<String>? seen,
}) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = _FakeFeedRepository(posts);
  await tester.pumpWidget(
    MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => FollowCubit(_NoOpProfileRepository())),
          BlocProvider(
            create: (_) => FeedCubit(
              repository: repository,
              userId: 'me',
              seenStore: _SeenStore(seen),
            ),
          ),
        ],
        child: ActivityFeedScreen(repository: repository, currentUserId: 'me'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('nowe posty: licznik, plakietki i separator przed starszymi',
      (tester) async {
    await _pump(
      tester,
      posts: [_post('n1'), _post('n2'), _post('old')],
      seen: ['old'],
    );

    expect(find.text('2 nowe treningi'), findsOneWidget);
    expect(find.byType(FeedNewBadge), findsNWidgets(2));
    expect(find.byType(FeedSeenDivider), findsOneWidget);
    expect(find.text('Przejrzałeś wszystkie nowe'), findsOneWidget);

    // Separator stoi między ostatnim nowym a pierwszym obejrzanym postem.
    final dividerY = tester.getTopLeft(find.byType(FeedSeenDivider)).dy;
    expect(tester.getTopLeft(find.text('Trening n2')).dy, lessThan(dividerY));
    expect(
      tester.getTopLeft(find.text('Trening old')).dy,
      greaterThan(dividerY),
    );
  });

  testWidgets('brak nowych: komunikat „jesteś na bieżąco” bez separatora',
      (tester) async {
    await _pump(tester, posts: [_post('a'), _post('b')], seen: ['a', 'b']);

    expect(find.text('Brak nowych treningów'), findsOneWidget);
    expect(find.byType(FeedNewBadge), findsNothing);
    expect(find.byType(FeedSeenDivider), findsNothing);
  });

  testWidgets('pierwsza wizyta: bez podsumowania', (tester) async {
    await _pump(tester, posts: [_post('a')], seen: null);

    expect(find.byType(FeedSeenSummaryBanner), findsNothing);
    expect(find.byType(FeedNewBadge), findsNothing);
  });

  testWidgets('same nowe posty: bez separatora (nie ma jeszcze starszych)',
      (tester) async {
    await _pump(tester, posts: [_post('n1')], seen: ['x']);

    expect(find.text('1 nowy trening'), findsOneWidget);
    expect(find.byType(FeedSeenDivider), findsNothing);
  });
}
