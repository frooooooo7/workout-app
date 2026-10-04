import '../models/workout_reminder.dart';

abstract class WorkoutReminderScheduler {
  /// Zastępuje wszystkie zaplanowane przypomnienia stanem z [reminder]
  /// (nieaktywne = odwołanie). Zwraca `false`, gdy system nie pozwala
  /// wysyłać powiadomień (brak zgody) — ustawienie i tak zostaje zapisane.
  Future<bool> apply(WorkoutReminder reminder);
}
