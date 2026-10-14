import 'dart:async';

import 'package:gym/features/feed/domain/models/feed_author.dart';
import 'package:gym/features/notifications/domain/models/app_notification.dart';
import 'package:gym/features/notifications/domain/repositories/notifications_repository.dart';

/// Repozytorium powiadomień w pamięci. `fail*` wymusza błąd danej operacji.
class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository({
    List<AppNotification> items = const [],
    this.settings = const NotificationSettings(),
    this.count = 0,
  }) : items = [...items];

  List<AppNotification> items;
  NotificationSettings settings;
  int count;

  bool failList = false;
  bool failWrites = false;
  bool failSettings = false;

  int listCalls = 0;
  int countCalls = 0;
  final readIds = <String>[];
  final dismissedIds = <String>[];
  int markAllCalls = 0;
  final savedSettings = <NotificationSettings>[];

  /// Gdy ustawione, `unreadCount` czeka na ręczne zakończenie.
  Completer<int>? pendingCount;

  /// Gdy ustawione, `updateSettings` czeka na ręczne zakończenie.
  Completer<void>? pendingSave;

  @override
  Future<NotificationsPage> list() async {
    listCalls++;
    if (failList) throw Exception('offline');
    return NotificationsPage(
      items: items,
      unreadCount: items.where((i) => !i.read).length,
    );
  }

  @override
  Future<int> unreadCount() {
    countCalls++;
    if (pendingCount case final pending?) return pending.future;
    return Future.value(count);
  }

  @override
  Future<void> markRead(String id) async {
    if (failWrites) throw Exception('offline');
    readIds.add(id);
  }

  @override
  Future<void> markAllRead() async {
    markAllCalls++;
    if (failWrites) throw Exception('offline');
  }

  @override
  Future<void> dismiss(String id) async {
    if (failWrites) throw Exception('offline');
    dismissedIds.add(id);
  }

  @override
  Future<NotificationSettings> getSettings() async {
    if (failSettings) throw Exception('offline');
    return settings;
  }

  @override
  Future<NotificationSettings> updateSettings(NotificationSettings s) async {
    savedSettings.add(s);
    if (pendingSave case final pending?) await pending.future;
    if (failSettings) throw Exception('offline');
    return settings = s;
  }
}

const anna = FeedAuthor(
  id: 'u-anna',
  firstName: 'Anna',
  lastName: 'Kowalska',
  handle: 'anna',
);
const kuba = FeedAuthor(
  id: 'u-kuba',
  firstName: 'Kuba',
  lastName: 'Nowak',
  handle: 'kuba',
);
const ola = FeedAuthor(
  id: 'u-ola',
  firstName: 'Ola',
  lastName: 'Wójcik',
  handle: 'ola',
);

final testNow = DateTime(2026, 10, 14, 12);

AppNotification kudosNotification({
  bool read = false,
  Duration ago = const Duration(minutes: 12),
  int count = 3,
}) => AppNotification(
  id: 'kudos:s-1',
  type: AppNotificationType.kudos,
  createdAt: testNow.subtract(ago),
  read: read,
  actors: const [anna, ola],
  actorCount: count,
  sessionId: 's-1',
  sessionTitle: 'Push',
);

AppNotification followNotification({
  bool read = false,
  bool isFollowing = false,
  Duration ago = const Duration(hours: 1),
}) => AppNotification(
  id: 'follow:u-kuba',
  type: AppNotificationType.follow,
  createdAt: testNow.subtract(ago),
  read: read,
  actors: const [kuba],
  isFollowing: isFollowing,
);

AppNotification planCopyNotification({bool read = true}) => AppNotification(
  id: 'plan_copy:c-1',
  type: AppNotificationType.planCopy,
  createdAt: testNow.subtract(const Duration(days: 2)),
  read: read,
  actors: const [ola],
  planId: 'p-1',
  planName: 'Góra A',
);

AppNotification recordNotification({bool read = true}) => AppNotification(
  id: 'record:s-2',
  type: AppNotificationType.record,
  createdAt: testNow.subtract(const Duration(days: 1)),
  read: read,
  actors: const [anna],
  sessionId: 's-2',
  sessionTitle: 'Pull',
  record: const NotificationRecord(
    exerciseName: 'Martwy ciąg',
    weightKg: 120,
    reps: 3,
  ),
);
