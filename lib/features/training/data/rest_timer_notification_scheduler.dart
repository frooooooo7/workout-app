import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/notifications/local_notifications.dart';
import '../domain/services/rest_timer_scheduler.dart';

class RestTimerNotificationScheduler implements RestTimerScheduler {
  RestTimerNotificationScheduler({LocalNotifications? notifications})
    : _local = notifications ?? LocalNotifications();

  static const int _notificationId = 9001;

  /// Stałe powiadomienie z odliczaniem na pasku (Android). Znika samo, gdy
  /// przerwa się kończy — wtedy dzwoni [_notificationId].
  static const int _countdownId = 9002;
  static const String _countdownChannelId = 'rest_timer_countdown';
  static const String _countdownChannelName = 'Odliczanie przerwy';
  static const String _countdownChannelDescription =
      'Pozostały czas przerwy na pasku powiadomień';
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
    await _showCountdown(duration);
  }

  /// Odliczanie na pasku powiadomień: systemowy chronometr liczy w dół do
  /// końca przerwy, więc działa też przy zablokowanym ekranie i bez
  /// odświeżania z aplikacji. Ciche — dźwięk daje dopiero koniec przerwy.
  Future<void> _showCountdown(Duration duration) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final endsAt = DateTime.now().add(duration);
    await _notifications.show(
      id: _countdownId,
      title: 'Odpoczynek',
      body: 'Koniec przerwy o ${_clock(endsAt)}',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _countdownChannelId,
          _countdownChannelName,
          channelDescription: _countdownChannelDescription,
          importance: Importance.low,
          priority: Priority.low,
          category: AndroidNotificationCategory.stopwatch,
          playSound: false,
          enableVibration: false,
          silent: true,
          onlyAlertOnce: true,
          ongoing: true,
          autoCancel: false,
          showWhen: true,
          when: endsAt.millisecondsSinceEpoch,
          usesChronometer: true,
          chronometerCountDown: true,
          timeoutAfter: duration.inMilliseconds,
        ),
      ),
    );
  }

  static String _clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}';

  @override
  Future<void> cancelRestFinished() async {
    if (kIsWeb) return;
    await _notifications.cancel(id: _notificationId);
    await _notifications.cancel(id: _countdownId);
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
