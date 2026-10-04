import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/notifications/local_notifications.dart';
import '../domain/models/workout_reminder.dart';
import '../domain/services/workout_reminder_scheduler.dart';

/// Jedno cotygodniowe powiadomienie na każdy wybrany dzień
/// (`dayOfWeekAndTime`), więc system powtarza je sam — także po restarcie
/// telefonu (boot receiver w manifeście).
class WorkoutReminderNotificationScheduler implements WorkoutReminderScheduler {
  WorkoutReminderNotificationScheduler({LocalNotifications? notifications})
    : _local = notifications ?? LocalNotifications();

  /// 9101 = poniedziałek … 9107 = niedziela.
  static int notificationIdFor(int weekday) => 9100 + weekday;

  static const String _channelId = 'workout_reminder';
  static const String _channelName = 'Przypomnienia o treningu';
  static const String _channelDescription =
      'Przypomnienia o treningu w wybrane dni tygodnia';

  final LocalNotifications _local;

  @override
  Future<bool> apply(WorkoutReminder reminder) async {
    if (kIsWeb) return true;

    await _local.ensureInitialized();
    for (var day = DateTime.monday; day <= DateTime.sunday; day++) {
      await _local.plugin.cancel(id: notificationIdFor(day));
    }
    if (!reminder.isActive) return true;

    final granted = await _local.requestNotificationsPermission();

    final now = tz.TZDateTime.now(tz.local);
    for (final weekday in reminder.weekdays) {
      final next = nextWorkoutReminderOccurrence(
        now: now,
        weekday: weekday,
        hour: reminder.hour,
        minute: reminder.minute,
      );
      await _local.plugin.zonedSchedule(
        id: notificationIdFor(weekday),
        title: 'Czas na trening',
        body: 'Masz dziś zaplanowany trening. Otwórz Stronger i zaczynaj!',
        scheduledDate: tz.TZDateTime(
          tz.local,
          next.year,
          next.month,
          next.day,
          next.hour,
          next.minute,
        ),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        // Przypomnienie nie musi być co do sekundy — bez zgody na dokładne alarmy.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
    return granted;
  }
}
