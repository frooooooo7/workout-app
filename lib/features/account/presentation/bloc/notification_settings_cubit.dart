import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../training/domain/services/rest_timer_notification_settings.dart';

class NotificationSettingsState {
  const NotificationSettingsState({
    this.loading = true,
    this.restTimerNotificationsEnabled = true,
    this.error,
  });

  final bool loading;
  final bool restTimerNotificationsEnabled;
  final String? error;
}

class NotificationSettingsCubit extends Cubit<NotificationSettingsState> {
  NotificationSettingsCubit(
    this._settings, {
    Future<void> Function()? onRestTimerNotificationsDisabled,
  }) : _onDisabled = onRestTimerNotificationsDisabled,
       super(const NotificationSettingsState());

  final RestTimerNotificationSettings _settings;

  /// Np. odwołanie powiadomienia zaplanowanego jeszcze przed wyłączeniem.
  final Future<void> Function()? _onDisabled;

  Future<void> load() async {
    final enabled = await _settings.isEnabled();
    if (isClosed) return;
    emit(
      NotificationSettingsState(
        loading: false,
        restTimerNotificationsEnabled: enabled,
      ),
    );
  }

  Future<void> setRestTimerNotificationsEnabled(bool enabled) async {
    final previous = state.restTimerNotificationsEnabled;
    emit(
      NotificationSettingsState(
        loading: false,
        restTimerNotificationsEnabled: enabled,
      ),
    );
    try {
      await _settings.setEnabled(enabled);
      if (!enabled) {
        try {
          await _onDisabled?.call();
        } catch (_) {
          /* ustawienie jest zapisane; odwołanie jest best-effort */
        }
      }
    } catch (_) {
      if (isClosed) return;
      emit(
        NotificationSettingsState(
          loading: false,
          restTimerNotificationsEnabled: previous,
          error: 'Nie udało się zapisać ustawienia. Spróbuj ponownie.',
        ),
      );
    }
  }
}
