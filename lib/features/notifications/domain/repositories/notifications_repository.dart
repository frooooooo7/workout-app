import '../models/app_notification.dart';

abstract interface class NotificationsRepository {
  Future<NotificationsPage> list();

  Future<int> unreadCount();

  Future<void> markRead(String id);

  Future<void> markAllRead();

  /// Ukrywa wpis, dopóki nie przyjdzie nowa aktywność (np. kolejny kudos).
  Future<void> dismiss(String id);

  Future<NotificationSettings> getSettings();

  /// Zapisuje całość ustawień i zwraca stan z serwera.
  Future<NotificationSettings> updateSettings(NotificationSettings settings);
}
