import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../domain/services/rest_timer_scheduler.dart';

class RestTimerNotificationScheduler implements RestTimerScheduler {
  RestTimerNotificationScheduler({
    FlutterLocalNotificationsPlugin? notifications,
  }) : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const int _notificationId = 9001;
  static const String _channelId = 'rest_timer_alarm';
  static const String _channelName = 'Timer odpoczynku';
  static const String _channelDescription =
      'Powiadomienia o końcu przerwy w aktywnym treningu';

  final FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;
  bool _timezoneInitialized = false;

  @override
  Future<void> scheduleRestFinished({required Duration duration}) async {
    if (kIsWeb || duration <= Duration.zero) return;

    await _ensureInitialized();
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

  Future<void> _ensureInitialized() async {
    if (!_timezoneInitialized) {
      tz.initializeTimeZones();
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
      _timezoneInitialized = true;
    }

    if (_initialized) return;

    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    await android?.requestFullScreenIntentPermission();

    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await ios?.requestPermissions(alert: true, sound: true);
  }
}
