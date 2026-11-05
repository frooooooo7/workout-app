import 'package:flutter_test/flutter_test.dart';
import 'package:gym/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:gym/features/notifications/presentation/bloc/notifications_state.dart';

import 'support/fake_notifications_repository.dart';

void main() {
  late FakeNotificationsRepository repository;
  late List<int> unread;

  NotificationsCubit build() =>
      NotificationsCubit(repository: repository, onUnreadChanged: unread.add);

  setUp(() {
    repository = FakeNotificationsRepository(
      items: [
        kudosNotification(),
        followNotification(),
        recordNotification(),
        planCopyNotification(),
      ],
    );
    unread = [];
  });

  test('unread items form the "new" section', () async {
    final cubit = build();
    await cubit.load();

    expect(cubit.state.status, NotificationsStatus.ready);
    expect(cubit.state.newItems.map((n) => n.id), [
      'kudos:s-1',
      'follow:u-kuba',
    ]);
    expect(cubit.state.earlierItems, hasLength(2));
    expect(unread, [2]);
  });

  test('reading keeps the item in "new" and only clears the dot', () async {
    final cubit = build();
    await cubit.load();

    await cubit.markRead(cubit.state.items.first);

    expect(repository.readIds, ['kudos:s-1']);
    expect(cubit.state.newItems.first.read, isTrue);
    expect(cubit.state.newItems, hasLength(2));
    expect(unread.last, 1);
  });

  test('mark all read is optimistic and rolls back on failure', () async {
    final cubit = build();
    await cubit.load();
    repository.failWrites = true;

    final pending = cubit.markAllRead();
    expect(cubit.state.unreadCount, 0);
    await pending;

    expect(cubit.state.unreadCount, 2);
    expect(cubit.state.notice?.message, contains('oznaczyć'));
    expect(unread, [2, 0, 2]);
  });

  test('a failed dismiss puts the item back in place', () async {
    final cubit = build();
    await cubit.load();
    repository.failWrites = true;

    final pending = cubit.dismiss(cubit.state.items[1]);
    expect(
      cubit.state.items.map((n) => n.id),
      isNot(contains('follow:u-kuba')),
    );
    await pending;

    expect(cubit.state.items[1].id, 'follow:u-kuba');
    expect(cubit.state.notice, isNotNull);
  });

  test('filters narrow both sections', () async {
    final cubit = build();
    await cubit.load();

    cubit.setFilter(NotificationFilter.records);

    expect(cubit.state.newItems, isEmpty);
    expect(cubit.state.earlierItems.single.id, 'record:s-2');
  });

  test(
    'a failed first load shows the error, a failed refresh keeps the list',
    () async {
      repository.failList = true;
      final cubit = build();
      await cubit.load();
      expect(cubit.state.status, NotificationsStatus.failure);

      repository.failList = false;
      await cubit.load();
      repository.failList = true;
      await cubit.refresh();

      expect(cubit.state.status, NotificationsStatus.ready);
      expect(cubit.state.items, hasLength(4));
      expect(cubit.state.notice?.message, contains('odświeżyć'));
    },
  );
}
