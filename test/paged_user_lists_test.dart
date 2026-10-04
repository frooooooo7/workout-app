import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym/core/network/api_client.dart';
import 'package:gym/features/feed/domain/repositories/feed_repository.dart';
import 'package:gym/features/feed/presentation/widgets/kudos_sheet.dart';
import 'package:gym/features/profile/domain/models/following_user.dart';
import 'package:gym/features/profile/domain/repositories/profile_repository.dart';
import 'package:gym/features/profile/presentation/bloc/follow_cubit.dart';
import 'package:gym/features/profile/presentation/screens/following_list_screen.dart';
import 'package:gym/features/profile/presentation/utils/paged_users.dart';
import 'package:gym/features/profile/presentation/widgets/paged_list_footer.dart';

FollowingUser _user(int i) => FollowingUser(
  id: 'u$i',
  firstName: 'Osoba',
  lastName: '$i',
  handle: 'osoba$i',
);

List<FollowingUser> _users(int count) => [
  for (var i = 0; i < count; i++) _user(i),
];

/// Strony z [all] po `limit` / `offset`, z logiem wywołań.
class _Pages {
  _Pages(this.all);

  final List<FollowingUser> all;
  final calls = <(int, int)>[];
  Object? failOnOffset;

  Future<List<FollowingUser>> fetch(int limit, int offset) async {
    calls.add((limit, offset));
    if (failOnOffset == offset) {
      failOnOffset = null;
      throw const ApiException('network_error');
    }
    return all.skip(offset).take(limit).toList();
  }
}

class _ProfileRepo extends Fake implements ProfileRepository {
  _ProfileRepo(this.pages);

  final _Pages pages;

  @override
  Future<List<FollowingUser>> getFollowers({int limit = 20, int offset = 0}) =>
      pages.fetch(limit, offset);
}

class _FeedRepo extends Fake implements FeedRepository {
  _FeedRepo(this.pages);

  final _Pages pages;

  @override
  Future<List<FollowingUser>> getKudos(
    String postId, {
    int limit = 50,
    int offset = 0,
  }) => pages.fetch(limit, offset);
}

void main() {
  group('PagedUsers', () {
    test('loads pages until a short one and skips duplicates', () async {
      final pages = _Pages(_users(45));
      final seeded = <String>[];
      final pager = PagedUsers(
        fetchPage: pages.fetch,
        onPage: (users) => seeded.addAll(users.map((u) => u.id)),
      );

      await pager.refresh();
      expect(pager.users, hasLength(20));
      expect(pager.hasMore, isTrue);

      // Ktoś doszedł na początek listy — offset przesuwa się o jedną osobę.
      pages.all.insert(0, _user(99));
      await pager.loadMore();
      expect(pager.users, hasLength(39));
      expect(pager.users.map((u) => u.id).toSet(), hasLength(39));

      await pager.loadMore();
      expect(
        pager.users,
        hasLength(45),
        reason: 'u99 sits before the loaded pages',
      );
      expect(pager.hasMore, isFalse);
      await pager.loadMore();
      expect(pages.calls, [(20, 0), (20, 20), (20, 40)]);
      expect(seeded, hasLength(45));
      pager.dispose();
    });

    test('a failed page keeps the list and can be retried', () async {
      final pages = _Pages(_users(30))..failOnOffset = 20;
      final pager = PagedUsers(fetchPage: pages.fetch);
      await pager.refresh();

      await pager.loadMore();
      expect(pager.moreFailed, isTrue);
      expect(pager.users, hasLength(20));

      await pager.loadMore();
      expect(pager.moreFailed, isFalse);
      expect(pager.users, hasLength(30));
      pager.dispose();
    });

    test('a refresh drops a page that was still loading', () async {
      final gate = Completer<void>();
      var call = 0;
      final pager = PagedUsers(
        pageSize: 2,
        fetchPage: (limit, offset) async {
          call++;
          if (call == 2) await gate.future;
          return [_user(offset), _user(offset + 1)];
        },
      );
      await pager.refresh();
      final stale = pager.loadMore();
      final fresh = pager.refresh();
      gate.complete();
      await stale;
      await fresh;
      expect(pager.users.map((u) => u.id), ['u0', 'u1']);
      pager.dispose();
    });
  });

  testWidgets('followers list loads the next page when scrolled to the end', (
    tester,
  ) async {
    final pages = _Pages(_users(30));
    final repo = _ProfileRepo(pages);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => FollowCubit(repo),
          child: FollowersListScreen(repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(pages.calls, [(20, 0)]);

    await tester.scrollUntilVisible(
      find.text('Osoba 29'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(pages.calls, [(20, 0), (20, 20)]);
    expect(find.byType(PagedListFooter), findsNothing);
  });

  testWidgets('followers list offers a retry when a page fails', (
    tester,
  ) async {
    final pages = _Pages(_users(25))..failOnOffset = 20;
    final repo = _ProfileRepo(pages);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => FollowCubit(repo),
          child: FollowersListScreen(repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
    await tester.pumpAndSettle();
    expect(pages.calls, [(20, 0), (20, 20)]);
    expect(find.byKey(pagedListRetryKey), findsOneWidget);

    await tester.tap(find.byKey(pagedListRetryKey));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView), const Offset(0, -3000), 3000);
    await tester.pumpAndSettle();

    expect(pages.calls, [(20, 0), (20, 20), (20, 20)]);
    expect(find.text('Osoba 24'), findsOneWidget);
    expect(find.byKey(pagedListRetryKey), findsNothing);
  });

  testWidgets('kudos sheet pages through givers', (tester) async {
    final pages = _Pages(_users(60));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KudosSheet(
            postId: 'p1',
            repository: _FeedRepo(pages),
            onUserTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(pages.calls, [(50, 0)]);

    await tester.scrollUntilVisible(
      find.text('Osoba 59'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(pages.calls, [(50, 0), (50, 50)]);
  });
}
