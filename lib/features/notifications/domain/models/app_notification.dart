import 'package:flutter/foundation.dart';

import '../../../feed/domain/models/feed_author.dart';

enum AppNotificationType {
  kudos('kudos'),
  follow('follow'),
  planCopy('plan_copy'),
  record('record');

  const AppNotificationType(this.apiName);

  final String apiName;

  static AppNotificationType? tryParse(String? value) {
    for (final type in values) {
      if (type.apiName == value) return type;
    }
    return null;
  }
}

/// Rekord osoby, którą obserwujesz: `Martwy ciąg 120 kg × 3`.
@immutable
class NotificationRecord {
  const NotificationRecord({
    required this.exerciseName,
    this.weightKg,
    this.reps,
  });

  final String exerciseName;
  final double? weightKg;
  final int? reps;
}

/// Wpis centrum powiadomień. Kudosy jednego treningu są zgrupowane:
/// [actors] to najnowsze osoby (do dwóch), [actorCount] — wszystkie.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.read,
    required this.actors,
    this.actorCount = 1,
    this.sessionId,
    this.sessionTitle,
    this.planId,
    this.planName,
    this.record,
    this.isFollowing = false,
  });

  final String id;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool read;
  final List<FeedAuthor> actors;
  final int actorCount;
  final String? sessionId;
  final String? sessionTitle;
  final String? planId;
  final String? planName;
  final NotificationRecord? record;

  /// Nowy obserwujący: czy już go obserwujesz („Obserwuj też”).
  final bool isFollowing;

  FeedAuthor get actor => actors.first;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    type: type,
    createdAt: createdAt,
    read: read ?? this.read,
    actors: actors,
    actorCount: actorCount,
    sessionId: sessionId,
    sessionTitle: sessionTitle,
    planId: planId,
    planName: planName,
    record: record,
    isFollowing: isFollowing,
  );
}

@immutable
class NotificationsPage {
  const NotificationsPage({required this.items, required this.unreadCount});

  final List<AppNotification> items;
  final int unreadCount;
}

/// Ciche godziny: `from`–`to` w formacie `HH:mm`, mogą przechodzić przez
/// północ (22:00–07:00).
@immutable
class QuietHours {
  const QuietHours({
    this.enabled = false,
    this.from = '22:00',
    this.to = '07:00',
  });

  final bool enabled;
  final String from;
  final String to;

  QuietHours copyWith({bool? enabled, String? from, String? to}) => QuietHours(
    enabled: enabled ?? this.enabled,
    from: from ?? this.from,
    to: to ?? this.to,
  );

  @override
  bool operator ==(Object other) =>
      other is QuietHours &&
      other.enabled == enabled &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(enabled, from, to);
}

/// Które rodzaje trafiają do centrum (i, po wdrożeniu, do push).
@immutable
class NotificationSettings {
  const NotificationSettings({
    this.kudos = true,
    this.follows = true,
    this.planCopies = true,
    this.records = true,
    this.quietHours = const QuietHours(),
  });

  final bool kudos;
  final bool follows;
  final bool planCopies;
  final bool records;
  final QuietHours quietHours;

  NotificationSettings copyWith({
    bool? kudos,
    bool? follows,
    bool? planCopies,
    bool? records,
    QuietHours? quietHours,
  }) => NotificationSettings(
    kudos: kudos ?? this.kudos,
    follows: follows ?? this.follows,
    planCopies: planCopies ?? this.planCopies,
    records: records ?? this.records,
    quietHours: quietHours ?? this.quietHours,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.kudos == kudos &&
      other.follows == follows &&
      other.planCopies == planCopies &&
      other.records == records &&
      other.quietHours == quietHours;

  @override
  int get hashCode =>
      Object.hash(kudos, follows, planCopies, records, quietHours);
}
