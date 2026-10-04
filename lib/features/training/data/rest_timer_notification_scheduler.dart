import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/notifications/local_notifications.dart';
import '../domain/services/rest_timer_scheduler.dart';

class RestTimerNotificationScheduler implements RestTimerScheduler {
  RestTimerNotificationScheduler({LocalNotifications? notifications})
    : _local = notifications ?? LocalNotifications();

  static const int _notificationId = 9001;
  static const String _channelId = 'rest_timer_alarm';
  static const String _channelName = 'Timer odpoczynku';
  static const String _channelDescription =
      'Powiadomienia o końcu przerwy w aktywnym treningu';

  final LocalNotifications _local;

  FlutterLocalNotificationsPlugin get _notifications => _local.plugin;

  @override
  Future<void> scheduleRestFinished({required Duration duration}) async {
    if (kIsWeb || duration <= Duration.zero) return;

    await _local.ensureInitialized();
    await _requestPermissions();
    await cancelRestFinished();

    final scheduledDate = tz.TZDateTime.now(tz.local).add(duration);
    await _notifications.zonedSchedule(
      id: _notificationId,
      title: 'Koniec przerwy',
      body: 'Czas wracać do ćwiczenia.',
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          playSound: true,
          enableVibration: true,
          fullScreenIntent: true,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelRestFinished() async {
    if (kIsWeb) return;
    await _notifications.cancel(id: _notificationId);
  }

  @override
  Future<void> warmUp() async {
    if (kIsWeb) return;
    await _local.ensureInitialized();
  }

  Future<void> _requestPermissions() async {
    await _local.requestNotificationsPermission();
    final android = _local.android;
    await android?.requestExactAlarmsPermission();
    await android?.requestFullScreenIntentPermission();
  }
}
