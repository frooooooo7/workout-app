import '../../../core/network/api_client.dart';
import '../../feed/data/feed_json.dart';
import '../domain/models/app_notification.dart';
import '../domain/repositories/notifications_repository.dart';

class ApiNotificationsRepository implements NotificationsRepository {
  const ApiNotificationsRepository(this._api);

  final ApiClient _api;

  static String _segment(String id) => Uri.encodeComponent(id);

  @override
  Future<NotificationsPage> list() async {
    final json = await _api.get('/notifications', auth: true);
    return pageFromJson(json as Map<String, dynamic>);
  }

  @override
  Future<int> unreadCount() async {
    final json = await _api.get('/notifications/unread-count', auth: true);
    return ((json as Map<String, dynamic>)['count'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<void> markRead(String id) =>
      _api.post('/notifications/${_segment(id)}/read', const {}, auth: true);

  @override
  Future<void> markAllRead() =>
      _api.post('/notifications/read-all', const {}, auth: true);

  @override
  Future<void> dismiss(String id) =>
      _api.delete('/notifications/${_segment(id)}', auth: true);

  @override
  Future<NotificationSettings> getSettings() async {
    final json = await _api.get('/notifications/settings', auth: true);
    return settingsFromJson(json as Map<String, dynamic>);
  }

  @override
  Future<NotificationSettings> updateSettings(
    NotificationSettings settings,
  ) async {
    final json = await _api.patch(
      '/notifications/settings',
      settingsToJson(settings),
      auth: true,
    );
    return settingsFromJson(json as Map<String, dynamic>);
  }

  static NotificationsPage pageFromJson(Map<String, dynamic> json) {
    final items = <AppNotification>[];
    for (final raw in (json['items'] as List? ?? const [])) {
      final item = notificationFromJson(raw as Map<String, dynamic>);
      // Nowszy serwer może dodać rodzaj, którego ta wersja nie zna.
      if (item != null) items.add(item);
    }
    return NotificationsPage(
      items: items,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  static AppNotification? notificationFromJson(Map<String, dynamic> json) {
    final type = AppNotificationType.tryParse(json['type'] as String?);
    final actors = [
      for (final actor in (json['actors'] as List? ?? const []))
        FeedJson.authorFromJson(actor as Map<String, dynamic>),
    ];
    if (type == null || actors.isEmpty) return null;
    final session = json['session'] as Map<String, dynamic>?;
    final plan = json['plan'] as Map<String, dynamic>?;
    final record = json['record'] as Map<String, dynamic>?;
    return AppNotification(
      id: json['id'] as String,
      type: type,
      createdAt: DateTime.parse(json['createdAt'] as String),
      read: json['read'] as bool? ?? false,
      actors: actors,
      actorCount: (json['actorCount'] as num?)?.toInt() ?? actors.length,
      sessionId: session?['id'] as String?,
      sessionTitle: session?['title'] as String?,
      planId: plan?['id'] as String?,
      planName: plan?['name'] as String?,
      record: record == null
          ? null
          : NotificationRecord(
              exerciseName: record['exerciseName'] as String? ?? '',
              weightKg: (record['weightKg'] as num?)?.toDouble(),
              reps: (record['reps'] as num?)?.toInt(),
            ),
      isFollowing: json['isFollowing'] as bool? ?? false,
    );
  }

  static NotificationSettings settingsFromJson(Map<String, dynamic> json) {
    final quiet = json['quietHours'] as Map<String, dynamic>? ?? const {};
    return NotificationSettings(
      kudos: json['kudos'] as bool? ?? true,
      follows: json['follows'] as bool? ?? true,
      planCopies: json['planCopies'] as bool? ?? true,
      records: json['records'] as bool? ?? true,
      quietHours: QuietHours(
        enabled: quiet['enabled'] as bool? ?? false,
        from: quiet['from'] as String? ?? '22:00',
        to: quiet['to'] as String? ?? '07:00',
      ),
    );
  }

  static Map<String, dynamic> settingsToJson(NotificationSettings s) => {
    'kudos': s.kudos,
    'follows': s.follows,
    'planCopies': s.planCopies,
    'records': s.records,
    'quietHours': {
      'enabled': s.quietHours.enabled,
      'from': s.quietHours.from,
      'to': s.quietHours.to,
    },
  };
}
