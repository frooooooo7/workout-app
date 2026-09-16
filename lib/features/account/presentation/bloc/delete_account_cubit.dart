import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/account_repository.dart';
import '../utils/account_error_messages.dart';

class DeleteAccountState {
  const DeleteAccountState({
    this.password = '',
    this.confirmed = false,
    this.unsyncedChanges = 0,
    this.deleting = false,
    this.error,
    this.deleted = false,
  });

  final String password;

  /// Zaznaczone „Rozumiem, że tej operacji nie można cofnąć”.
  final bool confirmed;

  /// Niewysłane/odrzucone zmiany lokalne — przepadną razem z kontem.
  final int unsyncedChanges;
  final bool deleting;
  final String? error;
  final bool deleted;

  bool get canSubmit =>
      password.isNotEmpty && confirmed && !deleting && !deleted;

  DeleteAccountState copyWith({
    String? password,
    bool? confirmed,
    int? unsyncedChanges,
    bool? deleting,
    String? error,
    bool clearError = false,
    bool? deleted,
  }) {
    return DeleteAccountState(
      password: password ?? this.password,
      confirmed: confirmed ?? this.confirmed,
      unsyncedChanges: unsyncedChanges ?? this.unsyncedChanges,
      deleting: deleting ?? this.deleting,
      error: clearError ? null : (error ?? this.error),
      deleted: deleted ?? this.deleted,
    );
  }
}

class DeleteAccountCubit extends Cubit<DeleteAccountState> {
  DeleteAccountCubit(this._repository, {Future<int> Function()? countUnsyncedChanges})
    : _countUnsyncedChanges = countUnsyncedChanges,
      super(const DeleteAccountState());

  final AccountRepository _repository;
  final Future<int> Function()? _countUnsyncedChanges;

  Future<void> loadUnsyncedChanges() async {
    final count = _countUnsyncedChanges;
    if (count == null) return;
    try {
      final value = await count();
      if (isClosed) return;
      emit(state.copyWith(unsyncedChanges: value));
    } catch (_) {
      /* ostrzeżenie jest pomocnicze */
    }
  }

  void passwordChanged(String value) =>
      emit(state.copyWith(password: value, clearError: true));

  void confirmationChanged(bool value) =>
      emit(state.copyWith(confirmed: value, clearError: true));

  /// Po sukcesie repozytorium kończy sesję (nawigacja do logowania), więc
  /// cubit zwykle jest już zamknięty, zanim zdąży wyemitować `deleted`.
  Future<void> submit() async {
    final snapshot = state;
    if (!snapshot.canSubmit) return;
    emit(snapshot.copyWith(deleting: true, clearError: true));
    try {
      await _repository.deleteAccount(password: snapshot.password);
      if (isClosed) return;
      emit(state.copyWith(deleting: false, deleted: true));
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          deleting: false,
          error: deleteAccountErrorMessage(error),
        ),
      );
    }
  }
}
