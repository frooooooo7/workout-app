import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/account_repository.dart';
import '../utils/account_error_messages.dart';

const kLogoutAllSuccessMessage =
    'Wylogowano ze wszystkich pozostałych urządzeń.';

/// Jednorazowy wynik dla SnackBara — [id] rośnie z każdą próbą.
class AccountActionResult {
  const AccountActionResult({
    required this.id,
    required this.message,
    required this.isError,
  });

  final int id;
  final String message;
  final bool isError;
}

class LogoutAllDevicesState {
  const LogoutAllDevicesState({this.inProgress = false, this.result});

  final bool inProgress;
  final AccountActionResult? result;
}

class LogoutAllDevicesCubit extends Cubit<LogoutAllDevicesState> {
  LogoutAllDevicesCubit(this._repository) : super(const LogoutAllDevicesState());

  final AccountRepository _repository;
  int _resultId = 0;

  Future<void> logoutAllDevices() async {
    if (state.inProgress) return;
    emit(LogoutAllDevicesState(inProgress: true, result: state.result));
    try {
      await _repository.logoutAllDevices();
      if (isClosed) return;
      emit(
        LogoutAllDevicesState(
          result: AccountActionResult(
            id: ++_resultId,
            message: kLogoutAllSuccessMessage,
            isError: false,
          ),
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        LogoutAllDevicesState(
          result: AccountActionResult(
            id: ++_resultId,
            message: logoutAllErrorMessage(error),
            isError: true,
          ),
        ),
      );
    }
  }
}
