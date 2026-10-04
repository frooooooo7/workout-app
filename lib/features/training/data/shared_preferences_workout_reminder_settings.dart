import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/workout_reminder.dart';
import '../domain/services/workout_reminder_settings.dart';

/// Ustawienie urządzenia (nie konta) — domyślnie wyłączone.
class SharedPreferencesWorkoutReminderSettings
    implements WorkoutReminderSettings {
  const SharedPreferencesWorkoutReminderSettings();

  static const enabledKey = 'workout_reminder_enabled';
  static const weekdaysKey = 'workout_reminder_weekdays';
  static const timeKey = 'workout_reminder_time_minutes';

  @override
  Future<WorkoutReminder> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedDays = prefs.getStringList(weekdaysKey);
      final weekdays = storedDays == null
          ? WorkoutReminder.defaultWeekdays
          : storedDays
                .map(int.tryParse)
                .whereType<int>()
                .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
                .toSet();
      final minutes = prefs.getInt(timeKey);
      const fallback = WorkoutReminder();
      final validMinutes = minutes != null && minutes >= 0 && minutes < 24 * 60
          ? minutes
          : fallback.hour * 60 + fallback.minute;
      return WorkoutReminder(
        enabled: prefs.getBool(enabledKey) ?? false,
        weekdays: weekdays,
        hour: validMinutes ~/ 60,
        minute: validMinutes % 60,
      );
    } catch (_) {
      return const WorkoutReminder();
    }
  }

  @override
  Future<void> save(WorkoutReminder reminder) async {
    final prefs = await SharedPreferences.getInstance();
    final days = reminder.weekdays.toList()..sort();
    await prefs.setBool(enabledKey, reminder.enabled);
    await prefs.setStringList(weekdaysKey, [for (final d in days) '$d']);
    await prefs.setInt(timeKey, reminder.hour * 60 + reminder.minute);
  }
}
