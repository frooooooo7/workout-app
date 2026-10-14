import 'package:flutter/foundation.dart';

import '../../domain/models/app_notification.dart';

enum NotificationsStatus { loading, ready, failure }

/// Filtry nad listą: „Wszystkie” i po jednym na rodzaj.
enum NotificationFilter {
  all('Wszystkie'),
  kudos('Kudosy'),
  follows('Obserwujący'),
  plans('Plany'),
  records('Rekordy');

  const NotificationFilter(this.label);

  final String label;

  bool matches(AppNotification item) => switch (this) {
    NotificationFilter.all => true,
    NotificationFilter.kudos => item.type == AppNotificationType.kudos,
    NotificationFilter.follows => item.type == AppNotificationType.follow,
    NotificationFilter.plans => item.type == AppNotificationType.planCopy,
    NotificationFilter.records => item.type == AppNotificationType.record,
  };
}

/// Jednorazowy komunikat (SnackBar) — [id] odróżnia dwa takie same.
@immutable
class NotificationsNotice {
  const NotificationsNotice(this.id, this.message);

  final int id;
  final String message;
}

@immutable
class NotificationsState {
  const NotificationsState({
    this.status = NotificationsStatus.loading,
    this.items = const [],
    this.newIds = const {},
    this.filter = NotificationFilter.all,
    this.refreshing = false,
    this.notice,
  });

  final NotificationsStatus status;
  final List<AppNotification> items;

  /// Nieprzeczytane w chwili wczytania listy. Sekcja „Nowe” trzyma je do
  /// następnego odświeżenia, więc oznaczenie nie przerzuca wierszy między
  /// sekcjami pod palcem — gaśnie tylko kropka.
  final Set<String> newIds;
  final NotificationFilter filter;
  final bool refreshing;
  final NotificationsNotice? notice;

  int get unreadCount => items.where((item) => !item.read).length;

  List<AppNotification> get _visible => filter == NotificationFilter.all
      ? items
      : items.where(filter.matches).toList(growable: false);

  List<AppNotification> get newItems =>
      _visible.where((item) => newIds.contains(item.id)).toList();

  List<AppNotification> get earlierItems =>
      _visible.where((item) => !newIds.contains(item.id)).toList();

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<AppNotification>? items,
    Set<String>? newIds,
    NotificationFilter? filter,
    bool? refreshing,
    NotificationsNotice? notice,
  }) => NotificationsState(
    status: status ?? this.status,
    items: items ?? this.items,
    newIds: newIds ?? this.newIds,
    filter: filter ?? this.filter,
    refreshing: refreshing ?? this.refreshing,
    notice: notice ?? this.notice,
  );
}
