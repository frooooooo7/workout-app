/// Operacje na koncie zalogowanego użytkownika. Błędy: `ApiException`.
abstract class AccountRepository {
  /// Zmienia hasło. Po sukcesie nowy token jest już zapisany, a pozostałe
  /// urządzenia wylogowane.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Unieważnia wszystkie tokeny; to urządzenie dostaje nowy.
  Future<void> logoutAllDevices();

  /// Trwale usuwa konto, a po sukcesie kończy sesję i czyści dane lokalne.
  Future<void> deleteAccount({required String password});
}
