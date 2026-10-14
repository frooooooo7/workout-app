import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:gym/features/notifications/presentation/bloc/notifications_state.dart';
import 'package:gym/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:gym/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:gym/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:gym/features/profile/domain/models/follow_result.dart';
import 'package:gym/features/profile/domain/repositories/profile_repository.dart';
import 'package:gym/features/profile/presentation/bloc/follow_cubit.dart';

import 'support/fake_notifications_repository.dart';

void main() {
  late FakeNotificationsRepository repository;
  late _FakeFollows follows;
  late List<int> unread;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: kNotificationsRoute,
      routes: [
        GoRoute(
          path: kNotificationsRoute,
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => FollowCubit(follows)),
              BlocProvider(
                create: (_) => NotificationsCubit(
                  repository: repository,
                  onUnreadChanged: unread.add,
                ),
              ),
            ],
            child: NotificationsScreen(now: testNow),
          ),
          routes: [
            GoRoute(
              path: 'settings',
              builder: (_, _) => const Text('USTAWIENIA'),
            ),
          ],
        ),
        GoRoute(
          path: '/app/posts/:id',
          builder: (_, s) => Text('POST ${s.pathParameters['id']}'),
        ),
        GoRoute(
          path: '/app/users/:id',
          builder: (_, s) => Text('PROFIL ${s.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repository = FakeNotificationsRepository(
      items: [
        kudosNotification(),
        followNotification(),
        recordNotification(),
        planCopyNotification(),
      ],
    );
    follows = _FakeFollows();
    unread = [];
  });

  testWidgets('new and earlier sections with readable text', (tester) async {
    await pump(tester);

    expect(find.text('NOWE · 2'), findsOneWidget);
    expect(find.text('WCZEŚNIEJ'), findsOneWidget);
    expect(
      find.text(
        'Anna i 2 inne osoby dają kudosy za trening Push',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('12 min temu'), findsOneWidget);
    expect(find.text('Obserwuj też'), findsOneWidget);
  });

  testWidgets('mark all read clears the counter but keeps the rows', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(notificationsMarkAllKey));
    await tester.pumpAndSettle();

    expect(repository.markAllCalls, 1);
    expect(find.text('NOWE'), findsOneWidget);
    expect(find.byKey(notificationsMarkAllKey), findsNothing);
    expect(find.byKey(notificationTileKey('kudos:s-1')), findsOneWidget);
    expect(unread.last, 0);
  });

  testWidgets('tapping a kudos opens the post and marks it read', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(notificationTileKey('kudos:s-1')));
    await tester.pumpAndSettle();

    expect(find.text('POST s-1'), findsOneWidget);
    expect(repository.readIds, ['kudos:s-1']);
  });

  testWidgets('a plan copy opens the copier profile', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(notificationTileKey('plan_copy:c-1')));
    await tester.pumpAndSettle();

    expect(find.text('PROFIL u-ola'), findsOneWidget);
  });

  testWidgets('follow back from the row', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(notificationFollowBackKey('u-kuba')));
    await tester.pumpAndSettle();

    expect(follows.followed, ['u-kuba']);
    expect(find.text('Obserwujesz'), findsOneWidget);
  });

  testWidgets('swiping removes the row', (tester) async {
    await pump(tester);

    await tester.drag(
      find.byKey(notificationTileKey('record:s-2')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(repository.dismissedIds, ['record:s-2']);
    expect(find.byKey(notificationTileKey('record:s-2')), findsNothing);
  });

  testWidgets('filters and the empty state', (tester) async {
    repository.items = [planCopyNotification()];
    await pump(tester);

    await tester.tap(
      find.byKey(notificationFilterKey(NotificationFilter.kudos)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Brak powiadomień tego rodzaju'), findsOneWidget);
  });

  testWidgets('offline first load offers a retry', (tester) async {
    repository.failList = true;
    await pump(tester);

    expect(find.text('Nie udało się wczytać powiadomień'), findsOneWidget);
    repository.failList = false;
    await tester.tap(find.text('Spróbuj ponownie'));
    await tester.pumpAndSettle();

    expect(find.text('NOWE · 2'), findsOneWidget);
  });

  testWidgets('the settings icon opens notification settings', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Ustawienia powiadomień'));
    await tester.pumpAndSettle();

    expect(find.text('USTAWIENIA'), findsOneWidget);
  });

  group('bell', () {
    testWidgets('badge shows the count and wiggles when it grows', (
      tester,
    ) async {
      final count = ValueNotifier(0);
      addTearDown(count.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NotificationBellButton(count: count, onPressed: () {}),
            ),
          ),
        ),
      );
      final badge = find.byKey(notificationBellBadgeKey);
      expect(tester.widget<AnimatedScale>(badge).scale, 0);

      count.value = 12;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final rotation = find.ancestor(
        of: find.byIcon(Icons.notifications_none_rounded),
        matching: find.byType(Transform),
      );
      expect(
        tester.widget<Transform>(rotation.first).transform.isIdentity(),
        isFalse,
      );
      await tester.pumpAndSettle();

      expect(tester.widget<AnimatedScale>(badge).scale, 1);
      expect(find.text('9+'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(NotificationBellButton)).label,
        'Powiadomienia, nieprzeczytane: 12',
      );
    });
  });
}

class _FakeFollows implements ProfileRepository {
  final followed = <String>[];

  @override
  Future<FollowResult> follow(String userId) async {
    followed.add(userId);
    return const FollowResult(isFollowing: true, followersCount: 1);
  }

  @override
  Future<FollowResult> unfollow(String userId) async =>
      const FollowResult(isFollowing: false, followersCount: 0);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
