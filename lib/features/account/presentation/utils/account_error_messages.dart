import '../../../../core/network/api_client.dart';
import '../../../../core/session/session_manager.dart';

const kAccountOfflineMessage =
    'Brak połączenia z internetem. Spróbuj ponownie, gdy będziesz online.';

String? _commonAccountError(Object error) {
  if (error is! ApiException) return null;
  if (error.statusCode == null) return kAccountOfflineMessage;
  if (isRevokedSessionError(error)) {
    return 'Sesja wygasła. Zaloguj się ponownie.';
  }
  if (error.statusCode == 429 || error.message == 'too_many_requests') {
    return 'Zbyt wiele prób. Spróbuj za chwilę.';
  }
  if (error.message == 'database_unavailable' ||
      (error.statusCode ?? 0) >= 500) {
    return 'Serwer chwilowo niedostępny. Spróbuj później.';
  }
  return null;
}

String changePasswordErrorMessage(Object error) {
  final common = _commonAccountError(error);
  if (common != null) return common;
  if (error is ApiException) {
    switch (error.message) {
      case 'invalid_credentials':
        return 'Obecne hasło jest nieprawidłowe.';
      case 'password_too_short':
        return 'Nowe hasło musi mieć co najmniej 8 znaków.';
      case 'password_too_weak':
        return 'Nowe hasło musi zawierać wielką literę i cyfrę.';
      case 'password_unchanged':
        return 'Nowe hasło musi różnić się od obecnego.';
      case 'missing_fields':
        return 'Uzupełnij wszystkie pola.';
    }
  }
  return 'Nie udało się zmienić hasła. Spróbuj ponownie.';
}

String logoutAllErrorMessage(Object error) {
  return _commonAccountError(error) ??
      'Nie udało się wylogować z pozostałych urządzeń. Spróbuj ponownie.';
}

String deleteAccountErrorMessage(Object error) {
  final common = _commonAccountError(error);
  if (common != null) return common;
  if (error is ApiException) {
    switch (error.message) {
      case 'invalid_credentials':
        return 'Nieprawidłowe hasło.';
      case 'missing_fields':
        return 'Podaj hasło, aby potwierdzić usunięcie konta.';
    }
  }
  return 'Nie udało się usunąć konta. Spróbuj ponownie.';
}
