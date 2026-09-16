import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/account_repository.dart';
import '../utils/account_error_messages.dart';
import 'change_password_state.dart';

class ChangePasswordCubit extends Cubit<ChangePasswordState> {
  ChangePasswordCubit(this._repository) : super(const ChangePasswordState());

  final AccountRepository _repository;

  void currentPasswordChanged(String value) =>
      emit(state.copyWith(currentPassword: value, clearError: true));

  void newPasswordChanged(String value) =>
      emit(state.copyWith(newPassword: value, clearError: true));

  void confirmPasswordChanged(String value) =>
      emit(state.copyWith(confirmPassword: value, clearError: true));

  Future<void> submit() async {
    final snapshot = state;
    if (!snapshot.canSubmit) return;
    emit(snapshot.copyWith(submitting: true, clearError: true));
    try {
      await _repository.changePassword(
        currentPassword: snapshot.currentPassword,
        newPassword: snapshot.newPassword,
      );
      if (isClosed) return;
      emit(state.copyWith(submitting: false, succeeded: true));
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copyWith(
          submitting: false,
          error: changePasswordErrorMessage(error),
        ),
      );
    }
  }
}
