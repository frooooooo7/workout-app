import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../training/domain/models/workout_reminder.dart';
import '../../../training/domain/services/workout_reminder_scheduler.dart';
import '../../../training/domain/services/workout_reminder_settings.dart';

class WorkoutReminderState {
  const WorkoutReminderState({
    this.loading = true,
    this.reminder = const WorkoutReminder(),
    this.permissionDenied = false,
    this.error,
  });

  final bool loading;
  final WorkoutReminder reminder;

  /// System zablokował powiadomienia — przypomnienie jest zapisane,
  /// ale telefon go nie pokaże.
  final bool permissionDenied;
  final String? error;
}

class WorkoutReminderCubit extends Cubit<WorkoutReminderState> {
  WorkoutReminderCubit(this._settings, this._scheduler)
    : super(const WorkoutReminderState());

  final WorkoutReminderSettings _settings;
  final WorkoutReminderScheduler _scheduler;

  /// Kolejne zmiany planujemy po kolei — inaczej szybkie klikanie dni
  /// mogłoby przeplatać odwołania i planowanie.
  Future<bool> _lastApply = Future.value(true);

  Future<void> load() async {
    final reminder = await _settings.load();
    if (isClosed) return;
    emit(WorkoutReminderState(loading: false, reminder: reminder));
  }

  Future<void> setEnabled(bool enabled) =>
      _update(state.reminder.copyWith(enabled: enabled));

  Future<void> toggleWeekday(int weekday) =>
      _update(state.reminder.toggleWeekday(weekday));

  Future<void> setTime(int hour, int minute) =>
      _update(state.reminder.copyWith(hour: hour, minute: minute));

  Future<void> _update(WorkoutReminder next) async {
    final previous = state.reminder;
    if (next == previous) return;
    emit(WorkoutReminderState(loading: false, reminder: next));
    try {
      await _settings.save(next);
    } catch (_) {
      if (isClosed) return;
      emit(
        WorkoutReminderState(
          loading: false,
          reminder: previous,
          error: 'Nie udało się zapisać przypomnienia. Spróbuj ponownie.',
        ),
      );
      return;
    }
    final apply = _lastApply.then((_) => _scheduler.apply(next));
    _lastApply = apply.catchError((_) => true);
    var granted = true;
    try {
      granted = await apply;
    } catch (_) {
      /* zapisane; zaplanuje się ponownie przy następnym starcie aplikacji */
    }
    if (isClosed || state.reminder != next) return;
    emit(
      WorkoutReminderState(
        loading: false,
        reminder: next,
        permissionDenied: next.isActive && !granted,
      ),
    );
  }
}
