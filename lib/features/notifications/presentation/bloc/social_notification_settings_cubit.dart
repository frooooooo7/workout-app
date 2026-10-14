import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';

@immutable
class SocialNotificationSettingsState {
  const SocialNotificationSettingsState({
    this.loading = true,
    this.settings,
    this.loadFailed = false,
    this.error,
    this.errorSeq = 0,
  });

  final bool loading;

  /// `null`, dopóki nie przyjdą z serwera.
  final NotificationSettings? settings;
  final bool loadFailed;
  final String? error;

  /// Odróżnia dwa takie same błędy zapisu (kolejny SnackBar).
  final int errorSeq;
}

/// Ustawienia powiadomień społecznościowych (zapisywane na serwerze).
/// Przełączniki zmieniają się od razu; zapisy idą po kolei, a przy błędzie
/// wraca ostatni stan potwierdzony przez serwer.
class SocialNotificationSettingsCubit
    extends Cubit<SocialNotificationSettingsState> {
  SocialNotificationSettingsCubit(this._repository)
    : super(const SocialNotificationSettingsState());

  final NotificationsRepository _repository;
  NotificationSettings? _confirmed;
  Future<void> _queue = Future.value();

  Future<void> load() async {
    emit(const SocialNotificationSettingsState());
    try {
      final settings = await _repository.getSettings();
      if (isClosed) return;
      _confirmed = settings;
      emit(SocialNotificationSettingsState(loading: false, settings: settings));
    } catch (_) {
      if (isClosed) return;
      emit(
        const SocialNotificationSettingsState(loading: false, loadFailed: true),
      );
    }
  }

  void setKudos(bool value) => _update((s) => s.copyWith(kudos: value));
  void setFollows(bool value) => _update((s) => s.copyWith(follows: value));
  void setPlanCopies(bool value) =>
      _update((s) => s.copyWith(planCopies: value));
  void setRecords(bool value) => _update((s) => s.copyWith(records: value));
  void setQuietHours(QuietHours value) =>
      _update((s) => s.copyWith(quietHours: value));

  Future<void> _update(
    NotificationSettings Function(NotificationSettings) change,
  ) {
    final current = state.settings;
    if (current == null || isClosed) return Future.value();
    emit(
      SocialNotificationSettingsState(
        loading: false,
        settings: change(current),
        errorSeq: state.errorSeq,
      ),
    );
    return _queue = _queue.then((_) => _save());
  }

  /// Wysyła najnowszy stan — kilka szybkich przełączeń to jeden zapis.
  Future<void> _save() async {
    final wanted = state.settings;
    if (isClosed || wanted == null || wanted == _confirmed) return;
    try {
      final saved = await _repository.updateSettings(wanted);
      _confirmed = saved;
      // Kolejna zmiana mogła już przyjść — zapisze ją następny krok kolejki.
      if (!isClosed && state.settings == wanted) {
        emit(
          SocialNotificationSettingsState(
            loading: false,
            settings: saved,
            errorSeq: state.errorSeq,
          ),
        );
      }
    } catch (_) {
      if (isClosed) return;
      emit(
        SocialNotificationSettingsState(
          loading: false,
          settings: _confirmed,
          error: 'Nie udało się zapisać ustawienia. Spróbuj ponownie.',
          errorSeq: state.errorSeq + 1,
        ),
      );
    }
  }
}
