import '../models/workout_reminder.dart';

abstract class WorkoutReminderSettings {
  Future<WorkoutReminder> load();

  Future<void> save(WorkoutReminder reminder);
}
