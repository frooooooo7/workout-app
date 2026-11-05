import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/notifications/local_notifications.dart';
import '../domain/services/warmup_goal_scheduler.dart';

/// Ciche powiadomienie „Rozgrzewka gotowa” po osiągnięciu celu czasu.
class WarmupGoalNotificationScheduler implements WarmupGoalScheduler {
  WarmupGoalNotificationScheduler({LocalNotifications? notifications})
    : _local = notifications ?? LocalNotifications();

  static const int notificationId = 9003;
  static const String _channelId = 'warmup_goal';
  static const String _channelName = 'Rozgrzewka';
  static const String _channelDescription =
      'Ciche powiadomienie po osiągnięciu celu czasu rozgrzewki';

  final LocalNotifications _local;

  FlutterLocalNotificationsPlugin get _notifications => _local.plugin;

  @override
  Future<void> scheduleGoalReached({required Duration after}) async {
    if (kIsWeb || after <= Duration.zero) return;

    await _local.ensureInitialized();
    await _local.requestNotificationsPermission();
    await cancelGoalReached();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: false,
        enableVibration: false,
        silent: true,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: false),
    );
    final scheduledDate = tz.TZDateTime.now(tz.local).add(after);

    Future<void> schedule(AndroidScheduleMode mode) =>
        _notifications.zonedSchedule(
          id: notificationId,
          title: 'Rozgrzewka gotowa',
          body: 'Cel czasu osiągnięty. Zacznij trening, kiedy chcesz.',
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: mode,
        );

    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      // Bez zgody na dokładne alarmy wystarczy przybliżony termin.
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  @override
  Future<void> cancelGoalReached() async {
    if (kIsWeb) return;
    await _local.ensureInitialized();
    await _notifications.cancel(id: notificationId);
  }
}
